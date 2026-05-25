#!/bin/sh
# ============================================================
# inst_maxx_strings.sh
#
# Fuegt die Uebersetzungen fuer die maxx3105-Devices in die
# translate.lang.stringtable.js (de + en) ein. Idempotent
# (grep-Check vor sed-Insert), und uninstall-faehig (gezieltes
# Loeschen unserer Eintraege).
#
# Anker: Zeile mit "noMoreKeys" - sehr stabiler Marker am Ende
# des stringTable-Blocks. Eintraege werden direkt davor eingefuegt.
#
# Hintergrund: ein patchsource-basierter Edit failed auf manchen
# OpenCCU-Builds (Offset-Drift, andere Eintragsanzahl). sed mit
# eindeutigem Wort-Anker ist robust gegen jedes Layout.
# ============================================================

ST_DE=/www/webui/js/lang/de/translate.lang.stringtable.js
ST_EN=/www/webui/js/lang/en/translate.lang.stringtable.js
WEBUI_JS=/www/webui/webui.js

# Counter fuer Logging-Summary (file-scope, reset in do_install)
ADDED=0
SKIPPED_PRESENT=0
SKIPPED_NOFILE=0

# Fuegt einen Eintrag vor der "noMoreKeys"-Zeile ein,
# wenn der Key noch nicht im File ist.
add_str() {
    local FILE="$1"
    local KEY="$2"
    local VAL="$3"
    if [ ! -f "${FILE}" ]; then
        SKIPPED_NOFILE=$((SKIPPED_NOFILE + 1))
        return 0
    fi
    if grep -qF "\"${KEY}\"" "${FILE}"; then
        SKIPPED_PRESENT=$((SKIPPED_PRESENT + 1))
        return 0
    fi
    # Anker: erste Zeile mit "noMoreKeys" - wir fuegen davor ein
    ANCHOR_LINE=$(grep -n '"noMoreKeys"' "${FILE}" | head -1 | cut -d: -f1)
    if [ -z "${ANCHOR_LINE}" ]; then
        echo "  ERROR: noMoreKeys anchor not found in $(basename ${FILE})"
        return 1
    fi
    INSERT_LINE=$((ANCHOR_LINE - 1))
    sed -i "${INSERT_LINE}a\\
    \"${KEY}\" : \"${VAL}\"," "${FILE}"
    ADDED=$((ADDED + 1))
    echo "  + $(basename ${FILE}): ${KEY}"
}

# Entfernt einen Eintrag (exakter Zeilen-Match auf Key).
del_str() {
    local FILE="$1"
    local KEY="$2"
    if [ ! -f "${FILE}" ]; then
        return 0
    fi
    # Loesche alle Zeilen die genau "    "KEY" :" enthalten
    sed -i "/\"${KEY}\"[[:space:]]*:/d" "${FILE}"
}

# Fuegt einen elvST-Mapping ParameterID -> stringTable-Key in webui.js ein.
# Wird von der Geraeteparameter-UI gelesen, um die rohen ParameterIDs
# (LATITUDE, LONGITUDE etc.) in lesbare Texte aufzuloesen.
# Idempotent: wenn der Key schon da ist, wird nichts gemacht.
add_elvst() {
    local PARAM="$1"
    local STKEY="$2"
    if [ ! -f "${WEBUI_JS}" ]; then
        SKIPPED_NOFILE=$((SKIPPED_NOFILE + 1))
        return 0
    fi
    # Eindeutige Pruefung: Zeile mit "elvST['PARAM'] = " (genau)
    if grep -qF "elvST['${PARAM}'] = " "${WEBUI_JS}"; then
        SKIPPED_PRESENT=$((SKIPPED_PRESENT + 1))
        return 0
    fi
    # Anker: existierende elvST-Zeile MAINTENANCE|UNREACH (sehr eindeutig,
    # gehoert zu jps Basis-Patch oder schon im Original)
    ANCHOR_LINE=$(grep -n "elvST\['MAINTENANCE|UNREACH'\]" "${WEBUI_JS}" | head -1 | cut -d: -f1)
    if [ -z "${ANCHOR_LINE}" ]; then
        echo "  ERROR: elvST['MAINTENANCE|UNREACH'] anchor not found in webui.js"
        return 1
    fi
    sed -i "${ANCHOR_LINE}a\\
elvST['${PARAM}'] = '\${${STKEY}}';" "${WEBUI_JS}"
    ADDED=$((ADDED + 1))
    echo "  + webui.js: elvST['${PARAM}']"
}

# Entfernt elvST-Eintrag aus webui.js.
del_elvst() {
    local PARAM="$1"
    if [ ! -f "${WEBUI_JS}" ]; then
        return 0
    fi
    sed -i "/^elvST\['${PARAM}'\][[:space:]]*=/d" "${WEBUI_JS}"
}

do_install() {
    echo "=== inst_maxx_strings.sh: install ==="
    ADDED=0
    SKIPPED_PRESENT=0
    SKIPPED_NOFILE=0

    # Deutsch
    add_str "${ST_DE}" "stringTableHbTemperatureOffset3" "Temperatur-Offset Sensor 3"
    add_str "${ST_DE}" "stringTableHbEc"                 "Elektrische Leitf%E4higkeit"
    add_str "${ST_DE}" "stringTableHbTds"                "TDS-Wert"
    add_str "${ST_DE}" "stringTableButtonOnBehavior"     "Verhalten beim Einschalten"
    add_str "${ST_DE}" "stringTableCharacteristic"       "Dimmkennlinie"
    add_str "${ST_DE}" "stringTableHbLatitude"           "Breitengrad"
    add_str "${ST_DE}" "stringTableHbLongitude"          "L%E4ngengrad"
    add_str "${ST_DE}" "stringTableHbTimezoneHours"      "Zeitzone (Stunden)"
    add_str "${ST_DE}" "stringTableHbSunOffsetMin"       "Sonnen-Offset (Minuten)"
    add_str "${ST_DE}" "stringTableHbMoonOffsetDays"     "Mond-Offset (Tage)"
    add_str "${ST_DE}" "stringTableHbCurrentTime"        "Aktuelle Zeit (UTC Unix-Epoch)"

    # Englisch (jp's en-File enthaelt deutlich weniger HB-Strings, daher
    # fuegen wir hier auch die ein, die in de bereits von jp da sind)
    add_str "${ST_EN}" "stringTableHbPh"                 "pH value"
    add_str "${ST_EN}" "stringTableHbOrp"                "ORP value"
    add_str "${ST_EN}" "stringTableHbToggleWaitTime"     "Relay switching delay"
    add_str "${ST_EN}" "stringTableHbFlowrate"           "Flow rate"
    add_str "${ST_EN}" "stringTableHbFlowrateQFactor"    "Flow sensor Q-factor"
    add_str "${ST_EN}" "stringTableHbTemperatureOffset1" "Temperature offset sensor 1"
    add_str "${ST_EN}" "stringTableHbTemperatureOffset2" "Temperature offset sensor 2"
    add_str "${ST_EN}" "stringTableHbTemperatureOffset3" "Temperature offset sensor 3"
    add_str "${ST_EN}" "stringTableHbEc"                 "Electrical conductivity"
    add_str "${ST_EN}" "stringTableHbTds"                "TDS value"
    add_str "${ST_EN}" "stringTableButtonOnBehavior"     "Power-on behavior"
    add_str "${ST_EN}" "stringTableCharacteristic"       "Dimming characteristic"
    add_str "${ST_EN}" "stringTableHbLatitude"           "Latitude"
    add_str "${ST_EN}" "stringTableHbLongitude"          "Longitude"
    add_str "${ST_EN}" "stringTableHbTimezoneHours"      "Timezone (hours)"
    add_str "${ST_EN}" "stringTableHbSunOffsetMin"       "Sun offset (minutes)"
    add_str "${ST_EN}" "stringTableHbMoonOffsetDays"     "Moon offset (days)"
    add_str "${ST_EN}" "stringTableHbCurrentTime"        "Current time (UTC Unix epoch)"

    # elvST-Mappings in webui.js: noetig damit die Geraeteparameter-UI
    # die rohen ParameterIDs (LATITUDE etc.) ueberhaupt als deutsche
    # Texte aufloest. Ohne diese Eintraege erscheint "LATITUDE" statt
    # "Breitengrad" im Geraete-Parameter-Dialog des HB-LC-Dim5-VIVA-CV
    # (dimmer_dev_master Parameter ohne Channel-Praefix + MAINTENANCE-
    # Variante als Backup fuer Status-Grid-Anzeige).
    add_elvst "LATITUDE"                "stringTableHbLatitude"
    add_elvst "LONGITUDE"               "stringTableHbLongitude"
    add_elvst "TIMEZONE_HOURS"          "stringTableHbTimezoneHours"
    add_elvst "SUN_OFFSET_MIN"          "stringTableHbSunOffsetMin"
    add_elvst "MOON_OFFSET_DAYS"        "stringTableHbMoonOffsetDays"
    add_elvst "CURRENT_TIME"            "stringTableHbCurrentTime"
    add_elvst "MAINTENANCE|LATITUDE"        "stringTableHbLatitude"
    add_elvst "MAINTENANCE|LONGITUDE"       "stringTableHbLongitude"
    add_elvst "MAINTENANCE|TIMEZONE_HOURS"  "stringTableHbTimezoneHours"
    add_elvst "MAINTENANCE|SUN_OFFSET_MIN"  "stringTableHbSunOffsetMin"
    add_elvst "MAINTENANCE|MOON_OFFSET_DAYS" "stringTableHbMoonOffsetDays"
    add_elvst "MAINTENANCE|CURRENT_TIME"    "stringTableHbCurrentTime"

    # POOL-WP-spezifische Mappings (HB_GENERIC|*)
    add_elvst "HB_GENERIC|HB_PH"                "stringTableHbPh"
    add_elvst "HB_GENERIC|HB_ORP"               "stringTableHbOrp"
    add_elvst "HB_GENERIC|HB_ORPOFFSET"         "stringTableHbOrpOffset"
    add_elvst "HB_GENERIC|HB_TOGGLEWAITTIME"    "stringTableHbToggleWaitTime"
    add_elvst "HB_GENERIC|HB_FLOW_RATE"         "stringTableHbFlowrate"
    add_elvst "HB_GENERIC|HB_FLOWRATE_QFACTOR"  "stringTableHbFlowrateQFactor"
    add_elvst "HB_GENERIC|UNI_PRESSURE"         "stringTableUniPressure"
    add_elvst "HB_GENERIC|TEMPERATURE_OFFSET"   "stringTableTemperatureOffset"
    add_elvst "HB_GENERIC|TEMPERATURE_OFFSET_1" "stringTableHbTemperatureOffset1"
    add_elvst "HB_GENERIC|TEMPERATURE_OFFSET_2" "stringTableHbTemperatureOffset2"
    add_elvst "HB_GENERIC|TEMPERATURE_OFFSET_3" "stringTableHbTemperatureOffset3"
    add_elvst "HB_GENERIC|HB_EC"                "stringTableHbEc"
    add_elvst "HB_GENERIC|HB_TDS"               "stringTableHbTds"

    # RGB-DW-CV-spezifische Mappings
    add_elvst "DIMMER|BUTTON_ON_BEHAVIOR"              "stringTableButtonOnBehavior"
    add_elvst "DUAL_WHITE_BRIGHTNESS|BUTTON_ON_BEHAVIOR" "stringTableButtonOnBehavior"
    add_elvst "DUAL_WHITE_BRIGHTNESS|CHARACTERISTIC"   "stringTableCharacteristic"

    echo "  summary: ${ADDED} added, ${SKIPPED_PRESENT} already present, ${SKIPPED_NOFILE} skipped (file missing)"
    echo "=== inst_maxx_strings.sh: install done ==="
}

do_uninstall() {
    echo "=== inst_maxx_strings.sh: uninstall ==="

    # Maxx3105-exklusive Keys (immer entfernen, weil jp die nicht hat)
    for F in "${ST_DE}" "${ST_EN}"; do
        del_str "${F}" "stringTableHbTemperatureOffset3"
        del_str "${F}" "stringTableHbEc"
        del_str "${F}" "stringTableHbTds"
        del_str "${F}" "stringTableButtonOnBehavior"
        del_str "${F}" "stringTableCharacteristic"
        del_str "${F}" "stringTableHbLatitude"
        del_str "${F}" "stringTableHbLongitude"
        del_str "${F}" "stringTableHbTimezoneHours"
        del_str "${F}" "stringTableHbSunOffsetMin"
        del_str "${F}" "stringTableHbMoonOffsetDays"
        del_str "${F}" "stringTableHbCurrentTime"
    done

    # Englisch-exklusive Keys (jp hat die nicht in en, daher von uns
    # eingefuegt; bei uninstall raus, falls die de-Variante davon noch
    # da bleibt schadet das auch nicht)
    del_str "${ST_EN}" "stringTableHbPh"
    del_str "${ST_EN}" "stringTableHbOrp"
    del_str "${ST_EN}" "stringTableHbToggleWaitTime"
    del_str "${ST_EN}" "stringTableHbFlowrate"
    del_str "${ST_EN}" "stringTableHbFlowrateQFactor"
    del_str "${ST_EN}" "stringTableHbTemperatureOffset1"
    del_str "${ST_EN}" "stringTableHbTemperatureOffset2"

    # elvST-Mappings in webui.js entfernen
    del_elvst "LATITUDE"
    del_elvst "LONGITUDE"
    del_elvst "TIMEZONE_HOURS"
    del_elvst "SUN_OFFSET_MIN"
    del_elvst "MOON_OFFSET_DAYS"
    del_elvst "CURRENT_TIME"
    del_elvst "MAINTENANCE|LATITUDE"
    del_elvst "MAINTENANCE|LONGITUDE"
    del_elvst "MAINTENANCE|TIMEZONE_HOURS"
    del_elvst "MAINTENANCE|SUN_OFFSET_MIN"
    del_elvst "MAINTENANCE|MOON_OFFSET_DAYS"
    del_elvst "MAINTENANCE|CURRENT_TIME"
    del_elvst "HB_GENERIC|HB_PH"
    del_elvst "HB_GENERIC|HB_ORP"
    del_elvst "HB_GENERIC|HB_ORPOFFSET"
    del_elvst "HB_GENERIC|HB_TOGGLEWAITTIME"
    del_elvst "HB_GENERIC|HB_FLOW_RATE"
    del_elvst "HB_GENERIC|HB_FLOWRATE_QFACTOR"
    del_elvst "HB_GENERIC|UNI_PRESSURE"
    del_elvst "HB_GENERIC|TEMPERATURE_OFFSET"
    del_elvst "HB_GENERIC|TEMPERATURE_OFFSET_1"
    del_elvst "HB_GENERIC|TEMPERATURE_OFFSET_2"
    del_elvst "HB_GENERIC|TEMPERATURE_OFFSET_3"
    del_elvst "HB_GENERIC|HB_EC"
    del_elvst "HB_GENERIC|HB_TDS"
    del_elvst "DIMMER|BUTTON_ON_BEHAVIOR"
    del_elvst "DUAL_WHITE_BRIGHTNESS|BUTTON_ON_BEHAVIOR"
    del_elvst "DUAL_WHITE_BRIGHTNESS|CHARACTERISTIC"

    echo "=== inst_maxx_strings.sh: uninstall done ==="
}

case "$1" in
    ""|install)   do_install   ;;
    uninstall)    do_uninstall ;;
    *)
        echo "Usage: $(basename $0) {install|uninstall}"
        exit 1
        ;;
esac
