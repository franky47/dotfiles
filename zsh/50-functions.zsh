function mkcd() { mkdir -p "$@" && eval cd "\"\$$#\""; }
alias get='curl -H "Accept:application/json" -D - '
function fixaudio() { ffmpeg -i "$@" -c:v copy -c:a ac3 -q:a 448 "ac3.$@" }
function getcert () {
  nslookup $1
  (openssl s_client -showcerts -servername $1 -connect $1:443 <<< "Q" | openssl x509 -text | grep -iA2 "Validity")
}

# Network
alias tcp='lsof -n -P -iTCP'
alias udp='lsof -n -P -iUDP'

# Crypto & data conversion
alias echon='echo -n'
alias lowercase="tr '[:upper:]' '[:lower:]'"
alias b64="base64 | sed 's/\//_/g' | sed 's/\+/-/g'"
alias b64d='base64 --decode'
alias x2b='xxd -r -p | b64'
alias b2x='b64d | xxd -p'
alias h2b='x2b'
alias b2h='b2x'
alias sha1="shasum -a 1 | cut -d ' ' -f 1"
alias sha256="shasum -a 256 | cut -d ' ' -f 1"
alias sha512="shasum -a 512 | cut -d ' ' -f 1"
alias prime='openssl prime -bits 256 -generate -hex -safe'
alias uuid='uuidgen | lowercase'
