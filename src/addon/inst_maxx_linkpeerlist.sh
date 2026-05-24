#!/bin/sh
# ============================================================
# inst_maxx_linkpeerlist.sh
#
# Fallback-Hook fuer den jp-Patch ic_linkpeerlist.cgi.patch
# Hunk 1 (HB-LC-Sw1PBU-FM-Liste, internal-Key-Ausblendung).
#
# Auf OpenCCU-Builds failed dieser Hunk haeufig mit
# "Possibly reversed hunk 1 at 728 / Hunk 1 FAILED 319/319",
# weil die ic_linkpeerlist.cgi auf der Live-CCU andere Zeilen-
# Nummern hat als jps patchsource-Snapshot. Der jp-Patch nutzt
# Zeilennummern und 3-Zeilen-Kontext, was bei OpenCCU-Drift bricht.
#
# Dieser Hook prueft idempotent (grep auf "HB-LC-Sw1PBU-FM"), ob
# der catch-Block bereits in /www/config/ic_linkpeerlist.cgi ist,
# und fuegt ihn falls noetig per sed mit eindeutigem Wort-Anker
# ('catch {set isHMW [isWired ...') ein.
#
# Nicht-destruktiv: wenn der jp-Patch erfolgreich war (z.B. auf
# einer perfekten OpenCCU-Snapshot-Version), tut dieser Hook nichts.
# ============================================================

ILP=/www/config/ic_linkpeerlist.cgi
MARKER="HB-LC-Sw1PBU-FM"

do_install() {
    echo "=== inst_maxx_linkpeerlist.sh: install ==="

    if [ ! -f "${ILP}" ]; then
        echo "  ic_linkpeerlist.cgi not found, skipping"
        return 0
    fi

    if grep -q "${MARKER}" "${ILP}" 2>/dev/null; then
        echo "  HB-LC-Sw*-FM block already present (jp patch worked or already injected), skipping"
        return 0
    fi

    # Anker: 'catch {set isHMW' kommt im File nur einmal vor.
    # Wir fuegen den catch-Block UNMITTELBAR DAVOR ein.
    ANCHOR_LINE=$(grep -n 'catch {set isHMW' "${ILP}" | head -1 | cut -d: -f1)
    if [ -z "${ANCHOR_LINE}" ]; then
        echo "  ERROR: 'catch {set isHMW' anchor not found in ic_linkpeerlist.cgi"
        return 1
    fi

    # In jps patchsource schliessen vor 'catch {set isHMW' zwei Klammern
    # (}-Ende des aeusseren Blocks, gefolgt von Leerzeile). Der Insert
    # soll davor (vor dem }) erfolgen. Daher: Anker auf die '      }' Zeile
    # eine Zeile vor 'catch {set isHMW'.
    # Suche rueckwaerts ab ANCHOR_LINE die naechste Zeile mit nur
    # Whitespace+'}' (das Ende des aeusseren if-Blocks).
    INSERT_BEFORE=$(awk -v end="${ANCHOR_LINE}" 'NR<end && /^[[:space:]]+\}[[:space:]]*$/ {last=NR} END{print last}' "${ILP}")
    if [ -z "${INSERT_BEFORE}" ]; then
        echo "  ERROR: closing brace before 'catch {set isHMW' not found"
        return 1
    fi
    INSERT_LINE=$((INSERT_BEFORE - 1))

    sed -i "${INSERT_LINE}a\\
        catch {\\
          set devType \$sender_descr(PARENT_TYPE)\\
          if {\\
           ([string equal -nocase \"HB-LC-Sw1PBU-FM\"       \$devType] == 1) ||\\
           ([string equal -nocase \"HB-LC-Sw2PBU-FM\"       \$devType] == 1) ||\\
           ([string equal -nocase \"HB-LC-Bl1PBU-FM\"       \$devType] == 1) ||\\
           ([string equal -nocase \"HB-LC-Sw1-FM\"          \$devType] == 1) ||\\
           ([string equal -nocase \"HB-LC-Sw2-FM\"          \$devType] == 1) ||\\
           ([string match -nocase \"HB-UNI-SenAct-4-4-SC*\" \$devType] == 1) ||\\
           ([string match -nocase \"HB-UNI-SenAct-8-8-SC*\" \$devType] == 1)\\
          } {\\
            #interne Tasten (InternalKeys) ausblenden, wenn Sender und Empfaenger die selbe Kanalnummer besitzen\\
            set sndCh [lindex [split \$link(SENDER)   \":\"] 1]\\
            set rcvCh [lindex [split \$link(RECEIVER) \":\"] 1]\\
            if { (\$sndCh == \$rcvCh) } {\\
              set internalLink  1\\
            } else {\\
              set internalLink  0\\
            }\\
            set hideBtnDelete 0\\
          }\\
        }" "${ILP}"
    echo "  inserted: HB-LC-Sw*-FM catch block after line ${INSERT_LINE}"

    echo "=== inst_maxx_linkpeerlist.sh: install done ==="
}

do_uninstall() {
    echo "=== inst_maxx_linkpeerlist.sh: uninstall ==="

    if [ ! -f "${ILP}" ]; then
        return 0
    fi

    if ! grep -q "${MARKER}" "${ILP}" 2>/dev/null; then
        return 0
    fi

    # Block-Loeschung: von 'catch {' davor bis '}' nach 'HB-LC-Sw1PBU-FM'.
    # Sed mit Range: Suche unsere Marker-Zeile, gehe rueckwaerts bis
    # naechstes 'catch {', und vorwaerts bis schliessendes '}' (8x).
    # Einfacher: sed Range mit eindeutigen Begrenzern.
    # Unser Block beginnt eindeutig mit dem 'catch {' direkt vor
    # 'set devType $sender_descr(PARENT_TYPE)' und endet mit dem '}'
    # nach 'set hideBtnDelete 0'. Loesche von 'set devType $sender_descr(PARENT_TYPE)'
    # rueckwaerts bis 'catch {' (1 Zeile) und vorwaerts bis '}' nach 'hideBtnDelete 0'.
    # Einfacher Ansatz: sed Range '/HB-LC-Sw1PBU-FM/,/^[[:space:]]*}[[:space:]]*$/'
    # wuerde zu viel loeschen. Daher zeilenweise:
    # 1. Loesche von der Zeile mit 'set devType $sender_descr(PARENT_TYPE)'
    #    9 Zeilen aufwaerts (catch { + Folgezeilen) bis zur schliessenden Klammer
    #    nach 'set hideBtnDelete 0'.
    # Robusterer Ansatz: awk
    awk '
        /^[[:space:]]+catch[[:space:]]*\{[[:space:]]*$/ {
            buf = $0 "\n"; in_block = 1; next
        }
        in_block {
            buf = buf $0 "\n"
            if (/HB-LC-Sw1PBU-FM/) is_ours = 1
            if (/^[[:space:]]+\}[[:space:]]*$/) {
                depth--
                if (depth <= 0) {
                    if (!is_ours) printf "%s", buf
                    buf = ""; in_block = 0; is_ours = 0; depth = 0
                    next
                }
            }
            if (/\{/) depth++
            next
        }
        { print }
    ' "${ILP}" > "${ILP}.tmp" && mv "${ILP}.tmp" "${ILP}"

    echo "=== inst_maxx_linkpeerlist.sh: uninstall done ==="
}

case "$1" in
    ""|install)   do_install   ;;
    uninstall)    do_uninstall ;;
    *)
        echo "Usage: $(basename $0) {install|uninstall}"
        exit 1
        ;;
esac
