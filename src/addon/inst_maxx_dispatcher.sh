#!/bin/sh
# ============================================================
# inst_maxx_dispatcher.sh
#
# Erweitert /www/rega/esp/datapointconfigurator.fn um die
# Renderer-Dispatch-Logik fuer den Channel-Typ HB_PROGRAM
# (genutzt von HB-LC-Dim5-VIVA-CV fuer die Biotop-Programm-Auswahl).
#
# Wird per inst_-Hook nach dem Patcher aufgerufen. Idempotent
# (laeuft Mehrfach-Aufrufe sauber durch, dank grep-Check).
#
# Hintergrund: ein patchsource-basierter Edit failed auf manchen
# OpenCCU-Builds, weil deren datapointconfigurator.fn nicht 1:1
# zu jps Build-Snapshot passt. sed-basierte Insertion mit grep-
# Anker ist robust gegen Layout-Drift.
# ============================================================

DPC_FN=/www/rega/esp/datapointconfigurator.fn
DPC_MARKER="CN_HB_PROGRAM"

do_install() {
    echo "=== inst_maxx_dispatcher.sh: install ==="

    if [ ! -f "${DPC_FN}" ]; then
        echo "  datapointconfigurator.fn not found, skipping"
        return 0
    fi

    if grep -q "${DPC_MARKER}" "${DPC_FN}" 2>/dev/null; then
        echo "  HB_PROGRAM dispatcher already present, skipping"
        return 0
    fi

    # --- Insert 1: Variable CN_HB_PROGRAM ---
    # Anker: Zeile mit "var CN_RGBW_COLOR" (eine der CN_*-Variable-Definitionen)
    ANCHOR1=$(grep -n 'var CN_RGBW_COLOR' "${DPC_FN}" | head -1 | cut -d: -f1)
    if [ -z "${ANCHOR1}" ]; then
        echo "  ERROR: CN_RGBW_COLOR anchor not found in datapointconfigurator.fn"
        return 1
    fi
    sed -i "${ANCHOR1}a\\
    var CN_HB_PROGRAM       = \"HB_PROGRAM.\";" "${DPC_FN}"
    echo "  inserted: var CN_HB_PROGRAM after line ${ANCHOR1}"

    # --- Insert 2: Dispatch-Block nach RGBW_AUTOMATIC ---
    # Anker: schliessende "}" nach Call("/esp/controls/rgbw.fn::CreateRGBWAutomaticControl()")
    ANCHOR2=$(grep -n 'CreateRGBWAutomaticControl' "${DPC_FN}" | head -1 | cut -d: -f1)
    if [ -z "${ANCHOR2}" ]; then
        echo "  ERROR: CreateRGBWAutomaticControl anchor not found"
        return 1
    fi
    # Block-Ende ist die naechste "}"-Zeile nach ANCHOR2
    BLOCK_END=$(awk -v start="${ANCHOR2}" 'NR>=start && /^[[:space:]]*\}[[:space:]]*$/ {print NR; exit}' "${DPC_FN}")
    if [ -z "${BLOCK_END}" ]; then
        echo "  ERROR: RGBW_AUTOMATIC block end not found"
        return 1
    fi
    sed -i "${BLOCK_END}a\\
\\
          !# CN_HB_PROGRAM\\
          bIsControl = ( sControlName.Find(CN_HB_PROGRAM) > -1 );\\
          if( bIsControl \\&\\& (sLastControlName != CN_HB_PROGRAM) )\\
          {\\
            WriteLine( \"<script>conInfo('Control CN_HB_PROGRAM found.');</script>\" );\\
            isKnownControl = true;\\
            sLastControlName = CN_HB_PROGRAM;\\
            Call(\"/esp/controls/hbprogram.fn::CreateHbProgramControl()\");\\
          }" "${DPC_FN}"
    echo "  inserted: HB_PROGRAM dispatch block after line ${BLOCK_END}"

    echo "=== inst_maxx_dispatcher.sh: install done ==="
}

do_uninstall() {
    echo "=== inst_maxx_dispatcher.sh: uninstall ==="

    if [ ! -f "${DPC_FN}" ]; then
        return 0
    fi

    if ! grep -q "${DPC_MARKER}" "${DPC_FN}" 2>/dev/null; then
        echo "  HB_PROGRAM dispatcher not present, nothing to remove"
        return 0
    fi

    # Dispatch-Block entfernen: von "!# CN_HB_PROGRAM" bis zur naechsten
    # "Call.*hbprogram" Zeile + 2 Folgezeilen (schliessende } + Leerzeile)
    sed -i '/!# CN_HB_PROGRAM/,/CreateHbProgramControl/d' "${DPC_FN}"
    # Variable entfernen
    sed -i '/var CN_HB_PROGRAM/d' "${DPC_FN}"
    # Verbleibende leere schliessende Block-Klammer + Leerzeile entfernen
    # (vorsichtig: nur wenn unmittelbar im Kontext eines kaputten Blocks)
    sed -i '/^[[:space:]]*}[[:space:]]*$/{N;/^[[:space:]]*}[[:space:]]*\n[[:space:]]*$/d}' "${DPC_FN}" 2>/dev/null

    echo "=== inst_maxx_dispatcher.sh: uninstall done ==="
}

case "$1" in
    ""|install)   do_install   ;;
    uninstall)    do_uninstall ;;
    *)
        echo "Usage: $(basename $0) {install|uninstall}"
        exit 1
        ;;
esac
