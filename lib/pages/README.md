# Pages structure

Scopul folderului `lib/pages/` este să conțină doar pagini de nivel înalt (route-level).

## Convenție recomandată

- `lib/pages/home_page.dart` – pagină principală după autentificare.
- `lib/pages/settings_page.dart` – setări cont/aplicație.
- `lib/pages/help_page.dart` – ajutor/FAQ.
- `lib/pages/profile_edit_page.dart` – modificare date cont.

## Reguli

- Componente reutilizabile stau în `lib/widgets/`.
- Logica de API stă în `lib/services/`.
- Form-urile stau în `lib/forms/`.
- `main.dart` orchestrează navigarea și state-ul global minim.

## Layout reutilizabil pentru pagini autentificate

Folosește `AuthenticatedPageShell` din `lib/widgets/authenticated_page_shell.dart` pentru:

- top bar comun,
- adaptare dark/light,
- meniu avatar profil,
- consistență vizuală între pagini.
