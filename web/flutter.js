_flutter = { loader: {} };
(function () {
  'use strict';
  _flutter.loader.load = function (config) {
    const { serviceWorkerSettings, onEntrypointLoaded } = config;
    const swVersion = (serviceWorkerSettings && serviceWorkerSettings.serviceWorkerVersion) || '1.0.0';
    const script = document.createElement('script');
    script.src = 'main.dart.js';
    script.defer = true;
    script.onload = function () {
      if (typeof _flutter.loader._onEntrypointLoaded === 'function') {
        _flutter.loader._onEntrypointLoaded(engineInitializer => {
          if (typeof onEntrypointLoaded === 'function') {
            onEntrypointLoaded(engineInitializer);
          }
        });
      }
    };
    document.body.appendChild(script);
  };
})();
