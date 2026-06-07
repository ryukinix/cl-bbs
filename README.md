# cl-bbs

An anonymous textboard (BBS) engine written in Common Lisp. It is a high-performance, modern clone of the original MIT Scheme **SchemeBBS** (which ran behind dis.4chan.org and world4ch /prog/).

## Features

- **Seamless SchemeBBS Layout:** Displays threads, index lists, and posts inside definition lists (`<dl>`, `<dt>`, `<dd>`) exactly conforming to the original SchemeBBS style.
- **Single Trailing Forms:** Conforms to the original textboard paradigm where a single posting form is rendered at the very end of the thread (no per-post forms).
- **Comprehensive Formatting Support:**
  - **Bold:** `**text**` -> `<b>text</b>`
  - **Italic:** `__text__` -> `<i>text</i>`
  - **Monospace:** \`text\` -> `<code>text</code>` (Uses the standard backtick notation)
  - **Spoilers:** `~~text~~` -> `<del>text</del>`
  - **Blockquotes:** Lines starting with `>` are rendered as `<blockquote>` blocks.
  - **Post References:** `>>7` are dynamically hyperlinked to jump anchors inside the thread page.
  - **Direct Image Link Previews:** Direct links to images (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`) are automatically converted into elegant clickable image previews.
  - **Standard URLs:** Standard URLs are automatically formatted as standard hyperlinks.
- **Dynamic Board Headers:** Centered and left-aligned board listing headers (e.g. `[ foo | prog ]`) are scanned and displayed dynamically at the top of every page.
- **Theme Preferences (Cookies):** Choose between multiple themes (`default`, `classic`, `dark`, `mona`, `no`) on the `/board/preferences` page. Selections are stored inside browser cookies (`theme`) and persistent.
- **Zero JavaScript Required:** The application is completely server-rendered.
- **Local Qlot Sandbox:** Locked sandbox dependencies pinned via `qlfile` to ensure backwards compatibility across environments.
- **29-Assertion Test Suite:** Comprehensive test coverage verifying cookies, routing pipelines, and formatting rules.

## Getting Started

### Prerequisites

You must have **Roswell** and **Qlot** installed:

```bash
# Install Roswell
# (Follow Roswell platform instructions)

# Install Qlot
ros install qlot
```

### Installation

Clone the repository and install dependencies locally:

```bash
# Fetch and lock dependencies locally
qlot install
```

### Running the Server

Start the Hunchentoot/Clack server:

```bash
make server
```
The server will boot and listen locally on port `8222`.

### Running Tests

Execute the automated Parachute test suite:

```bash
make check
```

## Software Stack

- **Lisp:** Common Lisp (SBCL) loaded via Roswell.
- **Web Server:** Hunchentoot, Clack, Lack.
- **HTML Templating:** `cl-who` (HTML generation).
- **Data Store:** S-expression files saved inside plain-text files under `data/sexp/`.
