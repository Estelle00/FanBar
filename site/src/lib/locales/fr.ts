import type { Dictionary } from "../i18n";

// French: home page only. Mode and menu names match the app's French
// interface; pages that exist only in English say so.
export const fr: Dictionary = {
  meta: {
    title: "FanBar — contrôle des ventilateurs du Mac, gratuit et open source",
    description:
      "FanBar est une app gratuite et open source pour la barre des menus du Mac : températures du CPU, du GPU, du SSD et de la batterie, vitesse des ventilateurs, vitesse fixe ou courbes selon la température.",
    ogDescription:
      "Contrôle des ventilateurs du Mac depuis la barre des menus, gratuit et open source : températures en direct, vitesse fixe et courbes modifiables.",
    keywords: [
      "FanBar",
      "contrôle ventilateur Mac",
      "vitesse ventilateur Mac",
      "température Mac",
      "température CPU Mac",
      "ventilateur MacBook bruyant",
      "AppleSMC",
      "alternative à Macs Fan Control",
    ],
  },
  nav: {
    highlights: "Points forts",
    screenshots: "Captures",
    howItWorks: "Fonctionnement",
    faq: "Questions",
    compare: "Comparer",
    releases: "Notes de version",
    compatibility: "Compatibilité",
    safety: "Sécurité",
    download: "Télécharger",
  },
  a11y: {
    mainNav: "Navigation principale",
    footerNav: "Navigation du pied de page",
    facts: "FanBar en chiffres",
    languageMenu: "Langue",
  },
  hero: {
    badge: "Gratuit · Open source · Natif macOS",
    titleLead: "Contrôle des ventilateurs Mac,",
    titleHighlight: "libre et gratuit.",
    subtitle:
      "FanBar est une app gratuite et open source pour la barre des menus du Mac. Surveillez les températures et la vitesse des ventilateurs, fixez une vitesse en tr/min ou créez des courbes selon la température. Fonctionne sous macOS 11 et versions ultérieures, sur les Mac Apple Silicon et Intel compatibles.",
    primaryCta: "Télécharger pour macOS",
    secondaryCta: "Voir sur GitHub",
    compatibilityCta: "Voir les preuves de compatibilité (en anglais)",
    caption: "MACOS 11+ · APPLE SILICON ET INTEL · DMG ET HOMEBREW",
  },
  stats: [
    { value: "11+", label: "macOS Big Sur et ultérieur" },
    { value: "6", label: "Modes de refroidissement, d’Auto à Extrême" },
    { value: "1 h", label: "Historique des températures, de 10 min à 1 h" },
    { value: "6", label: "Langues d’interface, sans redémarrer" },
  ],
  highlights: {
    badge: "Points forts",
    heading: "Tout pour comprendre et maîtriser les ventilateurs de votre Mac.",
    items: {
      status: {
        title: "État visible d’un coup d’œil",
        description: "Icône, température du CPU, vitesse moyenne ou les deux, côte à côte ou superposées.",
      },
      icons: {
        title: "Six icônes de barre des menus",
        description: "L’icône tourne avec les ventilateurs et ralentit jusqu’à l’arrêt quand ils s’arrêtent.",
      },
      widget: {
        title: "Widget de bureau",
        description: "Sous macOS 14 ou ultérieur : vitesse, vitesse de chaque ventilateur et mode sur le bureau.",
      },
      live: {
        title: "Visualisation en direct",
        description: "Chaque ventilateur affiche sa vitesse sur une jauge de 0 au maximum ; graphique de 10 min à 1 h.",
      },
      resources: {
        title: "Charge en un regard",
        description: "CPU, GPU, mémoire et disque dans une grille, avec un niveau indiqué par la couleur et par des mots.",
      },
      modes: {
        title: "Plusieurs modes",
        description: "Automatique, vitesse cible fixe, ou les profils Silencieux, Équilibré, Performance et Extrême.",
      },
      curves: {
        title: "Courbes de température",
        description: "Chaque profil a sa propre courbe modifiable, de la température à la vitesse.",
      },
      source: {
        title: "Source de température au choix",
        description: "CPU, GPU ou SSD pilote la courbe ; un capteur indisponible déclenche le repli de sécurité.",
      },
      alerts: {
        title: "Alertes de surchauffe",
        description: "Seuil réglable (60–105 °C) et son au choix ; un clic pour passer au refroidissement maximal.",
      },
      log: {
        title: "Journal CSV",
        description: "Températures, vitesses des ventilateurs et mode, toutes les 2 à 60 secondes, en fichiers CSV.",
      },
      safe: {
        title: "Sûr par défaut",
        description: "Les vitesses restent dans la plage matérielle ; en cas d’échec, macOS reprend la main.",
      },
      language: {
        title: "Six langues d’interface",
        description: "English, 简体中文, 繁體中文, 日本語, Русский ou Français, sans redémarrer.",
      },
    },
  },
  trust: {
    badge: "Conçu pour la confiance",
    heading: "Le contrôle manuel, seulement avec votre accord.",
    body: "Au quotidien, FanBar laisse macOS gérer le refroidissement, en silence et en toute sécurité. Le contrôle manuel n’est disponible qu’après votre autorisation explicite d’un helper privilégié signé ; au premier lancement, FanBar explique pourquoi il est nécessaire.",
    points: [
      "FanBar.app → XPC privilégié → helper signé (root) → AppleSMC",
      "Le helper lit les ventilateurs et fixe une cible bornée, sans écriture SMC arbitraire",
      "Les profils peuvent revenir en Automatique après 15 min, 30 min ou une heure",
      "Chaque version est notarisée par Apple ; le code source, helper compris, est public",
    ],
    cta: "FanBar est-il sûr ? Ce que le helper peut faire (en anglais)",
  },
  screenshots: {
    badge: "Interface",
    heading: "Une interface native et calme, pas un tableau de bord.",
    items: {
      popover: {
        alt: "Fenêtre de FanBar dans la barre des menus",
        title: "Fenêtre de la barre des menus",
        description: "Vitesse de chaque ventilateur, charge, températures et changement de mode.",
      },
      cooling: {
        alt: "Réglages de refroidissement de FanBar",
        title: "Courbes de refroidissement",
        description: "La courbe température → vitesse de chaque profil, à modifier librement.",
      },
      menubar: {
        alt: "Réglages d’affichage de FanBar dans la barre des menus",
        title: "Affichage dans la barre des menus",
        description: "Prévisualisez ce qu’affiche l’élément d’état avant de valider.",
      },
    },
  },
  howItWorks: {
    badge: "Fonctionnement",
    heading: "De l’installation au contrôle manuel en trois étapes.",
    steps: [
      {
        step: "01",
        title: "Lancez et lisez",
        description: "Ouvrez FanBar : la température et la vitesse des ventilateurs s’affichent dans la barre des menus.",
      },
      {
        step: "02",
        title: "Autorisez une fois",
        description: "La première fois que vous changez de mode, acceptez l’autorisation unique de macOS. Températures et vitesses s’affichent sans elle.",
      },
      {
        step: "03",
        title: "Choisissez un profil",
        description: "Un profil ou une vitesse fixe, avec retour en Automatique à tout moment.",
      },
    ],
  },
  faq: {
    badge: "Questions",
    heading: "Des réponses en langage clair.",
    body: "Compatibilité, autorisations, licence et ce que fait vraiment le contrôle manuel : des réponses courtes, sans marketing.",
    items: [
      {
        question: "Qu’est-ce que FanBar ?",
        answer:
          "FanBar est une app gratuite et open source pour la barre des menus de macOS. Elle affiche en direct les températures du CPU, du GPU, du SSD et de la batterie, et permet de régler manuellement la vitesse des ventilateurs. Elle fonctionne sous macOS 11 Big Sur et ultérieur, sur les Mac Apple Silicon et Intel qui exposent les données des ventilateurs via AppleSMC. Au quotidien, le refroidissement reste confié à macOS ; les modes manuels sont facultatifs et réversibles.",
      },
      {
        question: "FanBar est-il gratuit ? Faut-il un compte ?",
        answer:
          "Oui, FanBar est gratuit et open source sous licence GPL-3.0, sans compte, abonnement ni publicité. Les versions notarisées sont publiées sur GitHub Releases, et tout le code source, helper privilégié compris, est public.",
      },
      {
        question: "Quels Mac et quelles versions de macOS sont pris en charge ?",
        answer:
          "macOS 11 Big Sur ou ultérieur, sur les Mac Apple Silicon et Intel dont les données de ventilateurs sont lisibles via AppleSMC. Le widget de bureau nécessite macOS 14 ou ultérieur. Le service de contrôle s’enregistre via SMAppService sous macOS 13 et ultérieur, et via launchd sous macOS 11–12.",
      },
      {
        question: "FanBar a-t-il besoin des droits root ou d’un helper privilégié ?",
        answer:
          "Seulement pour le contrôle manuel des ventilateurs, et seulement après votre accord. FanBar.app communique avec le FanBarHelper signé via XPC privilégié : le helper s’exécute en root mais n’autorise aucune écriture SMC arbitraire ; il lit l’état des ventilateurs, fixe une cible bornée et rétablit le contrôle automatique. Si vous n’activez jamais le contrôle, le helper reste inactif.",
      },
      {
        question: "Quelles températures et vitesses FanBar peut-il lire ?",
        answer:
          "Les températures du CPU et du GPU sur tous les Mac pris en charge, et celles du SSD et de la batterie quand ces capteurs existent. FanBar lit la vitesse actuelle de chaque ventilateur ainsi que ses limites matérielles, et la barre des menus peut afficher l’icône, la température du CPU, la vitesse moyenne ou une combinaison. Des notifications facultatives se déclenchent quand le CPU ou le GPU atteint le seuil choisi, de 60 à 105 °C (90 °C par défaut).",
      },
      {
        question: "Quels modes de refroidissement FanBar propose-t-il ?",
        answer:
          "Six : Automatique (contrôle par macOS), une vitesse cible fixe, et les courbes des profils Silencieux, Équilibré, Performance et Extrême. Chaque profil a sa propre courbe température → vitesse modifiable et peut être épinglé au panneau de la barre des menus ; les profils peuvent revenir en Automatique après 15 minutes, 30 minutes ou une heure.",
      },
      {
        question: "Que se passe-t-il si le contrôle manuel échoue ou si l’app quitte ?",
        answer:
          "Les vitesses cibles restent dans la plage matérielle indiquée par chaque ventilateur, et FanBar rend le contrôle automatique à macOS quand un profil expire, quand l’app quitte ou perd la connexion, ou quand le service de contrôle échoue. Un réglage manuel ne continue jamais en silence en arrière-plan.",
      },
      {
        question: "Quelles langues FanBar prend-il en charge ?",
        answer:
          "Anglais, chinois simplifié, chinois traditionnel, japonais, russe et français. Choisissez Système ou une langue précise dans Réglages → Général → Langue de l’interface : le panneau de la barre des menus, les réglages, l’accueil et les messages d’état changent aussitôt, sans redémarrer.",
      },
    ],
  },
  finalCta: {
    badge: "Télécharger",
    heading: "Offrez à vos ventilateurs un travail plus calme.",
    body: "Versions notarisées pour Apple Silicon, Intel et universelles. Gratuit, open source, et honnête sur les compromis du contrôle manuel.",
    primaryCta: "Télécharger le .dmg",
    secondaryCta: "Voir sur GitHub",
    caption: "MACOS 11+ · APPLE SILICON ET INTEL · LICENCE GPL-3.0",
    latest: "Dernière version : FanBar {version}, publiée le {date}",
    latestLink: "Nouveautés (en anglais)",
  },
  footer: {
    copyright: "FanBar · Licence GPL-3.0",
    github: "GitHub",
    releases: "Notes de version (en anglais)",
  },
};
