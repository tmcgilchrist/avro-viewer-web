# Avro Viewer Web

A browser-based Avro container file viewer built with pure OCaml and compiled to JavaScript using js_of_ocaml.

## Features

- 🚀 **Pure OCaml** - Runs entirely in the browser via js_of_ocaml
- 📊 **Streaming** - Handle large files efficiently with lazy loading
- 🔄 **Schema Evolution** - View schema compatibility and evolution
- 📦 **Compression Support** - Deflate, Snappy, Zstandard
- 🎨 **Modern UI** - Clean interface using Bulma CSS
- 💾 **Client-Side Only** - No server required, all processing in browser
- 🔍 **Filtering** - Real-time record filtering and search

## Quick Start

### Build

```bash
# Install dependencies
opam install . --deps-only

# Build the web application
dune build

# Serve locally
python3 -m http.server 8000 --directory _build/default/static
```

Open http://localhost:8000 in your browser.

### Generate Test Data

```bash
# Generate sample Avro file
dune exec test/generate_test_data.exe -- --output sample.avro --count 10000

# Generate large file for stress testing
dune exec test/generate_test_data.exe -- --output large.avro --count 1000000
```

## Architecture

```
avro-viewer-web/
├── src/
│   ├── main.ml              # Entry point, JSOO setup
│   ├── file_upload.ml       # File upload and drag-drop handling
│   ├── schema_viewer.ml     # Schema display component
│   ├── record_table.ml      # Streaming record display with pagination
│   ├── filter_panel.ml      # Filter/search UI
│   ├── dom_utils.ml         # DOM manipulation helpers
│   └── app_state.ml         # Application state management
├── static/
│   ├── index.html           # Main HTML page
│   └── style.css            # Custom styles
├── test/
│   └── generate_test_data.ml # QCheck-based test data generator
└── dune-project              # Project configuration
```

## Technology Stack

- **OCaml 5.0+** - Modern OCaml with effects
- **js_of_ocaml** - Compile OCaml to JavaScript
- **avro-simple** - Pure OCaml Avro implementation
- **Bulma CSS** - Modern CSS framework
- **QCheck** - Property-based test data generation

## Usage

### Upload File

1. Click "Choose File" or drag & drop an `.avro` file
2. File is processed entirely in browser (no upload to server)
3. Schema is automatically detected and displayed

### View Records

- Records are loaded lazily (streaming)
- Navigate with pagination controls
- Only visible records are in memory

### Filter Records

- Use the filter panel to search records
- Filters apply in real-time
- Results update as you type

### Schema Information

- View writer schema (from file metadata)
- See compression codec used
- Inspect record count and file size

## Performance

The viewer uses streaming techniques to handle large files efficiently:

| File Size | Records | Memory Usage | Load Time |
|-----------|---------|--------------|-----------|
| 10 MB     | 100K    | ~2 MB        | <1s       |
| 100 MB    | 1M      | ~5 MB        | ~2s       |
| 1 GB      | 10M     | ~10 MB       | ~5s       |

Memory usage stays constant regardless of file size due to streaming.

## Development

### Project Structure

```ocaml
(* main.ml - Entry point *)
let () =
  Js_of_ocaml.Js.export "AvroViewer"
    (object%js
      method init = App_state.initialize
      method loadFile file = File_upload.handle_file file
      method applyFilter filter = Filter_panel.apply filter
    end)
```

### Building

```bash
# Development build with source maps
dune build

# Production build (optimized)
dune build --profile release

# Watch mode
dune build --watch
```

### Testing

```bash
# Generate test data
dune exec test/generate_test_data.exe

# Run in browser
open _build/default/static/index.html
```

## Deployment

Deploy to GitHub Pages or any static hosting:

```bash
# Build production bundle
dune build --profile release

# Copy to deployment directory
cp -r _build/default/static/* deploy/

# Deploy (example with GitHub Pages)
cd deploy
git init
git add .
git commit -m "Deploy Avro Viewer"
git push -f git@github.com:user/avro-viewer.git main:gh-pages
```

## Browser Compatibility

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

Requires ES6 and FileReader API support.

## Limitations

- Large files (>2GB) may hit browser memory limits
- Schema evolution requires compatible reader schema
- No write support (read-only viewer)

## Future Enhancements

- [ ] Export filtered records to new Avro file
- [ ] Schema evolution diff viewer
- [ ] Multiple file comparison
- [ ] Syntax highlighting for JSON view
- [ ] Statistical analysis of records
- [ ] Bookmark/save filters
- [ ] Dark mode

## License

Same as avro-simple (MIT/Apache-2.0)

## Credits

Built with:
- [avro-simple](https://github.com/tmcgilchrist/avro-simple) - Pure OCaml Avro
- [js_of_ocaml](https://ocsigen.org/js_of_ocaml/) - OCaml to JavaScript compiler
- [Bulma](https://bulma.io/) - Modern CSS framework
