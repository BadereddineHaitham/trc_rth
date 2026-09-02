/**
 * ZXing → jsQR shim for mobile_scanner web support.
 *
 * mobile_scanner 5.x calls ZXing.BrowserMultiFormatReader on the web.
 * ZXing JS 0.19.1 is unreliable on mobile browsers.
 * This shim exposes the exact same API but uses jsQR (v1.4) under the hood,
 * which is far more reliable on mobile cameras.
 *
 * Required: jsqr.min.js must be loaded BEFORE this script.
 */
(function () {
  'use strict';

  if (typeof jsQR === 'undefined') {
    console.error('[scanner_shim] jsQR is not loaded. QR scanning will not work.');
    return;
  }

  window.ZXing = window.ZXing || {};

  /**
   * Drop-in replacement for ZXing.BrowserMultiFormatReader.
   * @param {object} hints   - ZXing hints map (ignored, jsQR handles all formats)
   * @param {number} timeBetweenScansMillis - minimum ms between scan attempts
   */
  function BrowserMultiFormatReader(hints, timeBetweenScansMillis) {
    this._interval = timeBetweenScansMillis || 300;
    this._stream = null;
    this._videoElement = null;
    this._canvas = null;
    this._ctx = null;
    this._scanning = false;
    this._rafId = null;
  }

  // ── Properties ──────────────────────────────────────────────────────────────

  Object.defineProperty(BrowserMultiFormatReader.prototype, 'stream', {
    get: function () { return this._stream; }
  });

  Object.defineProperty(BrowserMultiFormatReader.prototype, 'videoElement', {
    get: function () { return this._videoElement; }
  });

  // ── Methods (accessed as JSFunction by Dart, called with callAsFunction) ───

  /**
   * Attach a MediaStream to a video element.
   * Returns a Promise that resolves when the video is playing.
   */
  BrowserMultiFormatReader.prototype.attachStreamToVideo = function (stream, videoElement) {
    var self = this;
    return new Promise(function (resolve) {
      self._stream = stream;
      self._videoElement = videoElement;
      videoElement.setAttribute('playsinline', 'true');
      videoElement.setAttribute('muted', 'true');
      videoElement.muted = true;
      videoElement.srcObject = stream;
      videoElement.onloadedmetadata = function () {
        videoElement.play().then(resolve).catch(resolve);
      };
      // Fallback in case onloadedmetadata already fired
      if (videoElement.readyState >= 1) {
        videoElement.play().then(resolve).catch(resolve);
      }
    });
  };

  /**
   * Continuously decode barcodes from the video element.
   * Calls callback(result, error) on each scan attempt.
   * result has a .text property when a QR code is found, else null.
   */
  BrowserMultiFormatReader.prototype.decodeContinuously = function (videoElement, callback) {
    var self = this;
    self._scanning = true;

    if (!self._canvas) {
      self._canvas = document.createElement('canvas');
      self._ctx = self._canvas.getContext('2d', { willReadFrequently: true });
    }

    var lastScan = 0;

    function tick(timestamp) {
      if (!self._scanning) return;

      if (timestamp - lastScan >= self._interval) {
        lastScan = timestamp;
        try {
          var vid = videoElement;
          if (vid && vid.readyState >= 2 && vid.videoWidth > 0 && vid.videoHeight > 0) {
            self._canvas.width = vid.videoWidth;
            self._canvas.height = vid.videoHeight;
            self._ctx.drawImage(vid, 0, 0);

            var imgData = self._ctx.getImageData(0, 0, self._canvas.width, self._canvas.height);
            var code = jsQR(imgData.data, imgData.width, imgData.height, {
              inversionAttempts: 'attemptBoth'
            });

            if (code && code.data) {
              callback({ text: code.data }, null);
            } else {
              callback(null, null);
            }
          }
        } catch (e) {
          callback(null, e);
        }
      }

      self._rafId = requestAnimationFrame(tick);
    }

    self._rafId = requestAnimationFrame(tick);
  };

  /**
   * Returns whether the video is currently playing.
   */
  BrowserMultiFormatReader.prototype.isVideoPlaying = function (videoElement) {
    return !!(videoElement &&
      !videoElement.paused &&
      !videoElement.ended &&
      videoElement.readyState > 2);
  };

  /**
   * Stop decoding without stopping the video stream.
   */
  BrowserMultiFormatReader.prototype.stopContinuousDecode = function () {
    this._scanning = false;
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }
  };

  /**
   * Fully reset the reader: stop scanning and release the camera stream.
   */
  BrowserMultiFormatReader.prototype.reset = function () {
    this.stopContinuousDecode();
    if (this._stream) {
      this._stream.getTracks().forEach(function (t) { t.stop(); });
      this._stream = null;
    }
    if (this._videoElement) {
      this._videoElement.srcObject = null;
      this._videoElement = null;
    }
  };

  // Register under ZXing namespace
  window.ZXing.BrowserMultiFormatReader = BrowserMultiFormatReader;
  console.log('[scanner_shim] ZXing.BrowserMultiFormatReader replaced with jsQR shim ✓');

})();
