#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-app}"

echo "⚙️  Initializing demo in $APP_DIR"

mkdir -p "$APP_DIR/templates/home"

# --- HomeController ---
if [ ! -f "$APP_DIR/src/Controller/HomeController.php" ]; then
  cat > "$APP_DIR/src/Controller/HomeController.php" <<'EOF'
<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;

class HomeController extends AbstractController
{
    #[Route('/', name: 'home')]
    public function index(): Response
    {
        return $this->render('home/index.html.twig', [
            'controller_name' => 'HomeController',
        ]);
    }

    #[Route('/health', name: 'health')]
    public function health(): Response
    {
        return new Response('OK', 200);
    }
}
EOF
  echo "✔ Created HomeController"
fi

# --- base.html.twig ---
if [ ! -f "$APP_DIR/templates/base.html.twig" ]; then
  cat > "$APP_DIR/templates/base.html.twig" <<'EOF'
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>{% block title %}My Symfony App{% endblock %}</title>
    {{ encore_entry_link_tags('app') }}
    {{ encore_entry_script_tags('app') }}
  </head>
  <body>
    <header>
      <strong>My Symfony App</strong>
      <nav>
        <a href="{{ path('home') }}">Home</a> ·
        <a href="{{ path('health') }}">Health</a>
      </nav>
    </header>
    <main class="container">
      {% block body %}{% endblock %}
    </main>
  </body>
</html>
EOF
  echo "✔ Created base.html.twig"
fi

# --- index.html.twig ---
if [ ! -f "$APP_DIR/templates/home/index.html.twig" ]; then
  cat > "$APP_DIR/templates/home/index.html.twig" <<'EOF'
{% extends 'base.html.twig' %}

{% block title %}Home{% endblock %}

{% block body %}
  <h1>Willkommen 🎉</h1>
  <p>Dieses Projekt wurde erfolgreich initialisiert.</p>
  <ul>
    <li>Controller: <span class="badge">{{ controller_name }}</span></li>
    <li>Assets: <span class="badge">encore app</span></li>
    <li>Healthcheck: <a href="{{ path('health') }}">/health</a></li>
  </ul>
{% endblock %}
EOF
  echo "✔ Created home/index.html.twig"
fi

# --- JS entrypoint ---
if [ ! -f "$APP_DIR/assets/app.js" ]; then
  cat > "$APP_DIR/assets/app.js" <<'EOF'
import './styles/app.scss';
console.log('Encore assets loaded');
EOF
  echo "✔ Created assets/app.js"
fi

# --- SCSS ---
if [ ! -f "$APP_DIR/assets/styles/app.scss" ]; then
  cat > "$APP_DIR/assets/styles/app.scss" <<'EOF'
:root { --brand: #0e76a8; }
h1 { color: var(--brand); }
EOF
  echo "✔ Created assets/styles/app.scss"
fi

# --- webpack.config.js ---
if [ ! -f "$APP_DIR/webpack.config.js" ]; then
  cat > "$APP_DIR/webpack.config.js" <<'EOF'
const Encore = require('@symfony/webpack-encore');

if (!Encore.isRuntimeEnvironmentConfigured()) {
  Encore.configureRuntimeEnvironment(process.env.NODE_ENV || 'dev');
}

Encore
  .setOutputPath('public/build/')
  .setPublicPath('/build')
  .addEntry('app', './assets/app.js')
  .splitEntryChunks()
  .enableSingleRuntimeChunk()
  .cleanupOutputBeforeBuild()
  .enableSourceMaps(!Encore.isProduction())
  .enableVersioning(Encore.isProduction())
  .enablePostCssLoader()
  .enableSassLoader();

module.exports = Encore.getWebpackConfig();
EOF
  echo "✔ Created webpack.config.js"
fi

echo "✅ Demo initialized in $APP_DIR"
