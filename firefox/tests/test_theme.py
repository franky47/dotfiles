import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile

from marionette_driver.marionette import Marionette


FIREFOX = os.environ.get("FIREFOX_BINARY", "/Applications/Firefox.app/Contents/MacOS/firefox")
THEME = Path(__file__).resolve().parents[1] / "chrome" / "classic-dark.css"


def inspect_theme(css, *, close_button_css="", collapsed=False, vertical=True):
    with tempfile.TemporaryDirectory(prefix="firefox-theme-test-") as directory:
        profile = Path(directory)
        (profile / "chrome").mkdir()
        (profile / "chrome/classic-dark.css").write_text(css)
        (profile / "chrome/tab-close-button.css").write_text(close_button_css)
        (profile / "chrome/userChrome.css").write_text(
            '@import url("classic-dark.css");\n@import url("tab-close-button.css");\n'
        )
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        prefs = {
            "marionette.port": port,
            "toolkit.legacyUserProfileCustomizations.stylesheets": True,
            "browser.nova.enabled": True,
            "sidebar.verticalTabs": vertical,
            "sidebar.revamp": True,
            "sidebar.position_start": False,
            "ui.systemUsesDarkTheme": 1,
            "ui.prefersReducedMotion": 1,
            "browser.shell.checkDefaultBrowser": False,
            "browser.startup.homepage_override.mstone": "ignore",
            "browser.aboutwelcome.enabled": False,
            "datareporting.policy.dataSubmissionEnabled": False,
        }
        (profile / "user.js").write_text("\n".join(
            f"user_pref({json.dumps(key)}, {json.dumps(value)});"
            for key, value in prefs.items()
        ))
        with (profile / "browser.log").open("w") as log:
            process = subprocess.Popen([
                FIREFOX, "--headless", "--no-remote", "--profile", directory,
                "--marionette", "--remote-allow-system-access", "about:blank",
            ], stdout=log, stderr=log)
            client = Marionette(port=port)
            try:
                client.raise_for_port(timeout=40)
                client.start_session()
                client.set_context("chrome")
                if collapsed:
                    client.execute_async_script("""
                        const done = arguments[arguments.length - 1];
                        SidebarController._state.launcherExpanded = false;
                        SidebarController.sidebarMain.requestUpdate();
                        SidebarController.sidebarMain.updateComplete.then(() =>
                            requestAnimationFrame(() => requestAnimationFrame(done)));
                    """)
                client.execute_script("gBrowser.selectedBrowser.focus();")
                result = client.execute_script("""
                    const root = getComputedStyle(document.documentElement);
                    const selectors = ["body", "#nav-bar", "#sidebar-container",
                        ".urlbar-background", ".tabbrowser-tab[selected] .tab-background"];
                    const elements = Object.fromEntries(selectors.map(selector => {
                        const el = document.querySelector(selector);
                        if (!el) throw new Error(`Missing element: ${selector}`);
                        const style = getComputedStyle(el);
                        const rect = el.getBoundingClientRect();
                        return [selector, {
                            background: style.backgroundColor,
                            image: style.backgroundImage,
                            border: style.borderTopColor,
                            geometry: [rect.x, rect.y, rect.width, rect.height],
                        }];
                    }));
                    return {elements, focus: root.getPropertyValue("--focus-outline-color").trim()};
                """)
                result["close_button"] = client.execute_script("""
                    const tab = gBrowser.selectedTab;
                    const button = tab.querySelector('.tab-close-button');
                    InspectorUtils.addPseudoClassLock(tab, ':hover');
                    InspectorUtils.addPseudoClassLock(button, ':hover');
                    const style = getComputedStyle(button);
                    const rect = button.getBoundingClientRect();
                    const scrollbox = document.getElementById('tabbrowser-arrowscrollbox')
                        .shadowRoot.querySelector('scrollbox');
                    return {
                        padding: getComputedStyle(tab).paddingTop,
                        outline: [style.outlineStyle, style.outlineWidth, style.outlineColor],
                        topClearance: rect.top - parseFloat(style.outlineWidth)
                            - parseFloat(style.outlineOffset) - scrollbox.getBoundingClientRect().top,
                        geometry: [rect.x, rect.y, rect.width, rect.height],
                    };
                """)
                result["close_button_focus_outline"] = client.execute_script("""
                    const button = gBrowser.selectedTab.querySelector('.tab-close-button');
                    InspectorUtils.addPseudoClassLock(button, ':focus-visible');
                    const style = getComputedStyle(button);
                    const outline = [style.outlineStyle, style.outlineWidth, style.outlineColor];
                    InspectorUtils.removePseudoClassLock(button, ':focus-visible');
                    return outline;
                """)
                result["focused_field"] = client.execute_script("""
                    gURLBar.focus();
                    return getComputedStyle(document.querySelector(".urlbar-background")).backgroundColor;
                """)
                client.set_context("content")
                client.navigate("data:text/html,<body style='background:rgb(10,20,30);color:rgb(40,50,60)'>Content</body>")
                result["content"] = client.execute_script("""
                    const style = getComputedStyle(document.body);
                    return [style.backgroundColor, style.color];
                """)
                return result
            except Exception:
                log.flush()
                print((profile / "browser.log").read_text())
                raise
            finally:
                try:
                    client.delete_session()
                except Exception:
                    pass
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


def main():
    baseline = inspect_theme("")
    themed = inspect_theme(THEME.read_text() if THEME.exists() else "")
    print(json.dumps({"baseline": baseline, "themed": themed}, indent=2))
    elements = themed["elements"]
    assert elements["body"]["background"] == "rgb(28, 27, 34)"
    assert elements["body"]["image"] == "none"
    assert elements["#nav-bar"]["background"] == "rgb(28, 27, 34)"
    assert elements[".urlbar-background"]["background"] == "rgba(0, 0, 0, 0.3)"
    assert elements[".tabbrowser-tab[selected] .tab-background"]["background"] == "rgba(106, 106, 120, 0.7)"
    assert themed["focus"] == "#00ddff"
    assert themed["focused_field"] == "rgb(66, 65, 77)"
    tab_image = elements[".tabbrowser-tab[selected] .tab-background"]["image"]
    assert "rgb(184, 156, 255)" not in tab_image
    assert "rgb(255, 149, 101)" not in tab_image
    assert themed["content"] == baseline["content"] == ["rgb(10, 20, 30)", "rgb(40, 50, 60)"]
    for selector in elements:
        assert elements[selector]["geometry"] == baseline["elements"][selector]["geometry"], selector
    print("PASS: classic colors, no frame gradient, same layout, unchanged web content")


if __name__ == "__main__":
    main()
