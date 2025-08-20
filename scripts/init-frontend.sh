#!/usr/bin/env bash
set -euo pipefail

# Use docker container for Composer & Node because nothing needs to be installed on local machine
# Creates only missing files - no replacement of existing

# Target-Symfony-Directory (Standard: app/)
APP_DIR="${APP_DIR:-app}"

# Helper function: Create files
write_if_absent () {
  local path="$1"
  local content="$2"
  if [ -f "$path" ]; then
    echo "⚠️  $path exists – jump to next."
  else
    mkdir -p "$(dirname "$path")"
    printf "%s" "$content" > "$path"
    echo "✅ create: $path"
  fi
}

echo "➡️  Check: Symfony-Directory: $APP_DIR"
test -d "$APP_DIR" || { echo "❌ $APP_DIR not found."; exit 1; }

# 1) Composer-Package (inside container, in app/)
echo "➡️  Install Symfony-Asset + Encore-Bundle (Composer)…"
docker compose run --rm composer \
  require symfony/asset symfony/webpack-encore-bundle

# 2) initialize package.json (when missing) + install Dev-Dependencies
echo "➡️  Install NPM Dev-Dependencies (Node-Container)…"
docker compose run --rm node sh -lc "
  cd /app
  [ -f package.json ] || npm init -y
  npm i -D @symfony/webpack-encore webpack webpack-cli \
    core-js regenerator-runtime \
    sass sass-loader css-loader mini-css-extract-plugin \
    babel-loader @babel/core @babel/preset-env
"

# 2b) Scripts in package.json (when not there yet)
echo "➡️  Add package.json-Scripts (build/dev/watch)…"
docker compose run --rm node sh -lc '
  cd /app
  node -e "
      const fs=require(\"fs\"); const p=\"./package.json\";
      if (!fs.existsSync(p)) process.exit(0);
      const pkg=JSON.parse(fs.readFileSync(p));
      pkg.scripts = pkg.scripts || {};
      if(!pkg.scripts.build) pkg.scripts.build = \"encore production\";
      if(!pkg.scripts.dev) pkg.scripts.dev = \"encore dev\";
      if(!pkg.scripts.watch) pkg.scripts.watch = \"encore dev --watch\";
      fs.writeFileSync(p, JSON.stringify(pkg, null, 2));
      console.log(\"✅ package.json scripts updated\");
    "
  '

# 3) webpack.config.js
WEBPACK_CFG='const Encore = require("@symfony/webpack-encore");

if (!Encore.isRuntimeEnvironmentConfigured()) {
  Encore.configureRuntimeEnvironment(process.env.NODE_ENV || "dev");
}

Encore
  .setOutputPath("public/build/")
  .setPublicPath("/build")
  .addEntry("app", "./assets/app.js")
  .splitEntryChunks()
  .enableSingleRuntimeChunk()
  .cleanupOutputBeforeBuild()
  .enableSourceMaps(!Encore.isProduction())
  .enableVersioning(Encore.isProduction())
  .configureBabelPresetEnv((options) => {
    options.useBuiltIns = "usage";
    options.corejs = 3;
  })
  .enableSassLoader()
;

module.exports = Encore.getWebpackConfig();
'
write_if_absent "$APP_DIR/webpack.config.js" "$WEBPACK_CFG"

# 4) assets/app.js
APP_JS='import "./styles/app.scss";
import "core-js/stable";
import "regenerator-runtime/runtime";

console.log("Encore is working ✅");
'
write_if_absent "$APP_DIR/assets/app.js" "$APP_JS"

# 5) assets/styles/app.scss
APP_SCSS=':root { --brand: #2d6cdf; }
body { font-family: system-ui, Arial, sans-serif; margin: 0; }
a { color: var(--brand); text-decoration: none; }
'
write_if_absent "$APP_DIR/assets/styles/app.scss" "$APP_SCSS"

# 6) .gitignore entree for public/build
if [ -f "$APP_DIR/.gitignore" ]; then
  if ! grep -qxF "/public/build/" "$APP_DIR/.gitignore"; then
    echo "/public/build/" >> "$APP_DIR/.gitignore"
    echo "✅ .gitignore: /public/build/ updated"
  fi
else
  echo "/public/build/" > "$APP_DIR/.gitignore"
  echo "✅ create: $APP_DIR/.gitignore (public/build ignore)"
fi

# 7) Twig-Note (only note, no Auto-Edit)
echo "ℹ️  Don't forget, to include templates/base.html.twig:"
echo '    {{ encore_entry_link_tags("app") }}  in <head>'
echo '    {{ encore_entry_script_tags("app") }}  bevor </body>'

# 8) First build
echo "➡️  First build (Node-Container)…"
docker compose run --rm node sh -lc "cd /app && npm run build || npx encore production"

echo "🎉 Done! Assets are in $APP_DIR/public/build"
