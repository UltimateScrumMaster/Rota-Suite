#!/usr/bin/env bash
# Copia los addons a la carpeta AddOns del juego.
# La ruta sale de la variable WOW_ADDONS_DIR o del archivo .wow-addons-path (una linea, fuera de git):
#   echo "/ruta/al/WoW/Interface/AddOns" > .wow-addons-path
WOW_ADDONS_DIR="${WOW_ADDONS_DIR:-}"
if [ -z "$WOW_ADDONS_DIR" ] && [ -f .wow-addons-path ]; then
  WOW_ADDONS_DIR="$(head -n 1 .wow-addons-path)"
fi

if [ -n "$WOW_ADDONS_DIR" ] && [ -d "$WOW_ADDONS_DIR" ]; then
  for addon in RotaProbe RotaCore RotaClass_DK RotaClass_PAL RotaClass_WAR RotaClass_ROG RotaClass_SHA RotaClass_WL RotaClass_MAG RotaClass_PRI RotaClass_HUN RotaClass_DRU RotaEditor; do
    if [ -d "$addon" ]; then
      rm -rf "${WOW_ADDONS_DIR:?}/$addon"
      cp -r "$addon" "$WOW_ADDONS_DIR/$addon"
      echo "[OK] Sincronizado: $addon -> $WOW_ADDONS_DIR/$addon"
    fi
  done
else
  echo "[INFO] Carpeta AddOns no configurada (WOW_ADDONS_DIR o .wow-addons-path). Los paquetes estan en dist/"
fi
