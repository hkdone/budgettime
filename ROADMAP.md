# Roadmap BudgetTime — phases planifiées

## En cours / terminé

| Sprint | Statut | Contenu |
|--------|--------|---------|
| **Sprint 1** | ✅ Déployé (tests inbox en attente sync banque) | Rapprochement souple |
| **Sprint 2** | ✅ Code prêt | Fix solde double comptage (`origin`), sync solde découplée |
| **Sprint 3** | ✅ Code prêt | UX inbox (tri par match, badge, confirmation) |
| **Sprint 4** | À faire | Auto-liaison IBAN persistante après changement clé API |

## Phase additionnelle (demandée)

| Sprint | Statut | Contenu |
|--------|--------|---------|
| **Sprint 5** | À faire | **Gestionnaires de mots de passe** (Bitwarden / Proton Pass) — autofill login |

### Sprint 5 — détail du problème

Le formulaire de login a déjà `AutofillHints.username/email/password`, mais les gestionnaires ne remplissent pas automatiquement sur le déploiement Synology (HTTPS auto-signé, accès par IP, PWA).

**Pistes à investiguer lors de l'implémentation :**

1. Envelopper le formulaire dans un `AutofillGroup` + `TextInput.finishAutofillContext()` après login réussi
2. Vérifier les attributs HTML générés (`autocomplete="username"` / `current-password`) côté Flutter Web
3. Formulaire HTML natif de secours dans `web/index.html` (technique connue pour PWAs Flutter)
4. Certificat auto-signé + URL IP (`192.168.x.x`) : les extensions ne matchent souvent pas l'entrée enregistrée (domaine / URL différente)
5. Mode PWA installé vs onglet navigateur (origines différentes pour le coffre)
6. Documenter pour l'utilisateur : enregistrer l'URL exacte utilisée (`https://IP:8097`)

**Fichiers concernés :** `login_page.dart`, `signup_page.dart`, `web/index.html`

---

## Workflow de test (préférence utilisateur)

```powershell
./release.ps1 -Version "2.4.18-test1" -Message "Test Synology Sprint 1"
# Push GitHub ? → n
# Build Docker ?  → n
# Puis copier budgettime/ sur le NAS
```
