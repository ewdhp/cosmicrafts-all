// src/utils/polyfills.js
if (typeof globalThis === 'undefined') {
      (function () {
        if (typeof self !== 'undefined') {
          self.globalThis = self;
        } else if (typeof window !== 'undefined') {
          window.globalThis = window;
        } else if (typeof global !== 'undefined') {
          global.globalThis = global;
        } else {
          // Fallback
          (function () {
            this.globalThis = this;
          })();
        }
      })();
    }
    