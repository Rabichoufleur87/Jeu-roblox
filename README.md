# Jeu Roblox - Simulator (clique + argent)

Un mini-jeu "Simulator" complet : le joueur clique sur une sphère pour gagner
de l'argent (Cash), achète des améliorations (plus d'argent par clic, un
auto-clicker qui rapporte de l'argent tout seul), et peut faire un
**Rebirth** pour repartir à zéro contre un multiplicateur permanent. La
progression est sauvegardée automatiquement (DataStore).

Toute l'interface (le menu avec les boutons) est générée par script : tu n'as
rien à construire toi-même dans Studio à part créer les 3 scripts ci-dessous.

## Installation dans Roblox Studio

1. Ouvre Roblox Studio, crée ou ouvre ton lieu (place).
2. Dans l'**Explorer**, clique droit sur **ReplicatedStorage** → *Insert
   Object* → **ModuleScript**. Renomme-le en `GameConfig`. Colle le contenu
   de [`ReplicatedStorage/GameConfig.lua`](ReplicatedStorage/GameConfig.lua).
3. Clique droit sur **ServerScriptService** → *Insert Object* → **Script**.
   Renomme-le en `SimulatorServer`. Colle le contenu de
   [`ServerScriptService/SimulatorServer.lua`](ServerScriptService/SimulatorServer.lua).
4. Déplie **StarterPlayer**, clique droit sur **StarterPlayerScripts** →
   *Insert Object* → **LocalScript**. Renomme-le en `SimulatorClient`. Colle
   le contenu de
   [`StarterPlayerScripts/SimulatorClient.lua`](StarterPlayerScripts/SimulatorClient.lua).
5. Va dans **Game Settings** (Accueil → Game Settings) → onglet **Security**
   → active **Enable Studio Access to API Services** (nécessaire pour que la
   sauvegarde fonctionne pendant les tests dans Studio).
6. Clique sur **Play**. La sphère jaune "CLIQUE-MOI !" apparaît, ainsi que le
   menu en bas à gauche.

Aucune autre étape n'est nécessaire : le script serveur crée automatiquement
la sphère cliquable, les RemoteEvents et les statistiques (`leaderstats`).

## Récapitulatif de l'arborescence attendue

```
ReplicatedStorage
└── GameConfig            (ModuleScript)

ServerScriptService
└── SimulatorServer        (Script)

StarterPlayer
└── StarterPlayerScripts
    └── SimulatorClient    (LocalScript)
```

## Comment ça marche

- **GameConfig** centralise les formules d'équilibrage (coût des
  améliorations, gains, rebirth). Modifie ces valeurs pour ajuster la
  difficulté/progression.
- **SimulatorServer** gère tout ce qui doit rester fiable côté serveur :
  argent du joueur, achats, sauvegarde (DataStore), revenu passif.
- **SimulatorClient** construit l'interface et affiche les données envoyées
  par le serveur.

## Pistes pour aller plus loin

- Ajouter plusieurs zones/mondes avec des sphères de plus en plus rentables.
- Ajouter des œufs/animaux compagnons (comme Pet Simulator).
- Ajouter un classement (leaderboard) des joueurs les plus riches.
- Passer les gros nombres en notation scientifique si `Cash` dépasse
  ~2 milliards (limite d'un `IntValue`).
