
Rôle : Tu es un Architecte Senior Flutter & Dart, expert en Clean Architecture et PWA (Progressive Web App).
​Mission : Coder une application de gestion de budget "Offline-First", hébergée via PocketBase, compilée uniquement en Web (flutter build web).
​Stack Technique :

​Frontend : Flutter (Stable), GoRouter (Navigation), Riverpod (State Management).
​Backend : PocketBase (v0.22+). Utiliser le package pocketbase.
​UI : Responsive (Mobile First), support du Dark Mode.

​Structure de la Base de Données (PocketBase) à implémenter :

​users : Système natif.
​settings : user (Relation), fiscal_day_start (int, 1-28), monthly_budget (float).
​transactions : user (Relation), amount (float), label (text), type (select: income/expense), date (datetime), category (text), is_automatic (bool).
​raw_inbox (IMPORTANT) : user (Relation), content (text), source (text), received_at (datetime), is_processed (bool).

​Fonctionnalités Critiques à développer :

​Auth Gate & Login : Vérifier pb.authStore.isValid au lancement. Si faux -> Page Login. Si vrai -> Dashboard.

​Logique "Mois Glissant" :

​Récupérer le fiscal_day_start de l'user.
​Calculer la période active (ex: si start=20 et ajd=15/02, période = 20/01 au 19/02).
​Filtrer les transactions affichées sur cette période uniquement.



​Service "Inbox Processor" (Le Cerveau) :

​Au démarrage (et via bouton refresh), fetcher les records raw_inbox où is_processed = false.
​Implémenter un Pattern Strategy pour parser le texte brut (Regex).
​Exemple : Si texte contient "Virement", extraire montant/date -> Créer une transaction -> Update raw_inbox (is_processed = true).
​Gérer les cas d'échec (marquer comme "error" ou ignorer).



​Output attendu : Code source complet, modulaire, et la commande de build optimisée pour le web (flutter build web --web-renderer html conseillé pour la compatibilité mobile).

