from test_theme import THEME, inspect_theme


fix = (THEME.parent / "tab-close-button.css").read_text()

for name, colors in [("default", ""), ("classic dark", THEME.read_text())]:
    baseline = inspect_theme(colors, collapsed=True)
    fixed = inspect_theme(colors, close_button_css=fix, collapsed=True)
    assert baseline["close_button"]["outline"][:2] == ["solid", "1px"], name
    assert fixed["close_button"]["outline"][:2] == ["none", "0px"], name
    for key in ["padding", "geometry"]:
        assert fixed["close_button"][key] == baseline["close_button"][key], (name, key)
    assert fixed["elements"] == baseline["elements"], name
    assert fixed["close_button_focus_outline"] == baseline["close_button_focus_outline"], name
    assert fixed["close_button_focus_outline"][:2] == ["solid", "1px"], name
    print(f"PASS: {name}, no hover outline, same spacing, keyboard-focus outline retained")

for name, vertical in [("expanded vertical", True), ("horizontal", False)]:
    baseline = inspect_theme("", vertical=vertical)
    fixed = inspect_theme("", close_button_css=fix, vertical=vertical)
    assert fixed["close_button"] == baseline["close_button"], name
    assert fixed["elements"] == baseline["elements"], name
    assert fixed["close_button_focus_outline"] == baseline["close_button_focus_outline"], name
    print(f"PASS: {name} unchanged")
