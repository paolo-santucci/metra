# Métra — Jekyll Theme

Un tema Jekyll minimalista basato sul Design System di Métra.

## Installazione

```bash
bundle install
bundle exec jekyll serve
```

## Struttura

```
metra-jekyll/
├── _config.yml          # Configurazione Jekyll
├── _layouts/
│   ├── default.html     # Layout base (header + footer)
│   ├── home.html        # Home con griglia post
│   ├── post.html        # Singolo post
│   └── page.html        # Pagina generica
├── _sass/
│   ├── _tokens.scss     # Design tokens (colori, tipografia, spacing)
│   ├── _base.scss       # Reset e stili base
│   ├── _layout.scss     # Header, footer, griglia, card
│   └── _syntax.scss     # Syntax highlighting (Rouge)
└── assets/css/
    └── main.scss        # Entry point CSS
```

## Token principali

| Token | Valore | Uso |
|---|---|---|
| `$sabbia` | `#F4EDE2` | Background principale |
| `$terracotta` | `#C87456` | Accento primario |
| `$inchiostro` | `#2B2521` | Testo primario |
| `$lavanda` | `#5B4E7A` | Link, previsioni |
| `$malva` | `#9E7488` | Accento secondario |

## Font

- **Display**: DM Serif Display (Google Fonts)
- **Body**: Inter (Google Fonts)
- **Mono**: JetBrains Mono / Fira Code (sistema)
