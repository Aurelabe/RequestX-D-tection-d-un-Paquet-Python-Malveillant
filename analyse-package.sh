#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo"
  exit 1
fi

PACKAGE_NAME=$1
MISTRAL_HOST="ip.host"
MISTRAL_PORT="port.host"

if [ -z "$PACKAGE_NAME" ]; then
  echo "Usage: $0 <nom_du_package>"
  exit 1
fi

# Créer un dossier temporaire
TMP_DIR=$(mktemp -d)
echo "[*] Création du dossier temporaire $TMP_DIR"

# Installer le package dans un conteneur Docker sandboxé depuis TestPyPI
echo "[*] Installation sandboxée de $PACKAGE_NAME depuis TestPyPI dans Docker..."
docker run --rm -v "$TMP_DIR":/sandbox python:3.13-slim bash -c "\
pip install --index-url https://test.pypi.org/simple/ --no-deps $PACKAGE_NAME && \
cd /usr/local/lib/python3.13/site-packages && \
tar -cf /sandbox/package_files.tar $PACKAGE_NAME*"

# Extraire le contenu pour analyse
tar -xf "$TMP_DIR/package_files.tar" -C "$TMP_DIR"
echo "[*] Contenu du package copié pour analyse"

# Construire un JSON avec le contenu de chaque fichier Python
FILES_JSON="["
FIRST=true
while IFS= read -r FILE; do
    CONTENT=$(jq -Rs . < "$FILE")
    BASENAME=$(basename "$FILE")
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        FILES_JSON+=","
    fi
    FILES_JSON+="{\"file\":\"$BASENAME\",\"content\":$CONTENT}"
done < <(find "$TMP_DIR" -name "*.py" -type f)
FILES_JSON+="]"

# Préparer le prompt pour Mistral
PROMPT="Analyse tous ces fichiers Python et pour chacun retourne UNIQUEMENT un JSON au format {\"file\":\"nom_du_fichier\",\"verdict\":\"safe|malicious\",\"details\":\"...\"} : $FILES_JSON"

# Créer le fichier JSON pour curl
PROMPT_FILE="$TMP_DIR/prompt.json"
jq -n --arg model "mistral:latest" \
      --arg prompt "$PROMPT" \
      --arg stream "false" \
      '{model: $model, prompt: $prompt, stream: ($stream | test("true"))}' > "$PROMPT_FILE"

# Appeler Mistral
echo "[*] Analyse du package par Mistral..."
RESPONSE=$(curl -s --data-binary "@$PROMPT_FILE" -H "Content-Type: application/json" \
    http://$MISTRAL_HOST:$MISTRAL_PORT/api/generate)

VERDICTS=$(echo "$RESPONSE" | jq -r '.response // empty' | jq '.')

echo "[*] Verdicts Mistral par fichier :"
echo "$VERDICTS"

# Vérifie si au moins un fichier est malicieux
MALICIOUS_COUNT=$(echo "$VERDICTS" | jq 'map(select(.verdict=="malicious")) | length')
if [ "$MALICIOUS_COUNT" -gt 0 ]; then
    echo -e "\n[!] Le package semble malicieux ou suspect. Installation NON recommandée."
else
    echo -e "\n[*] Tous les fichiers sont sûrs."
    read -p "Voulez-vous installer le package dans un venv temporaire depuis TestPyPI ? (y/n) : " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        # Créer un venv temporaire
        VENV_DIR="$TMP_DIR/venv"
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate"

        echo "[*] Installation de $PACKAGE_NAME dans le venv depuis TestPyPI..."
        pip install --upgrade pip
        pip install --index-url https://test.pypi.org/simple/ "$PACKAGE_NAME"

        echo "[*] Package installé dans le venv temporaire : $VENV_DIR"
        echo "[*] Pour l'utiliser : source $VENV_DIR/bin/activate"

        deactivate
    else
        echo "[*] Installation annulée."
    fi
fi

# Nettoyer le dossier temporaire (sauf le venv si installé)
if [ ! -d "$VENV_DIR" ]; then
    rm -rf "$TMP_DIR"
    echo "[*] Dossier temporaire supprimé."
else
    echo "[*] Dossier temporaire conservé pour le venv : $VENV_DIR"
fi
