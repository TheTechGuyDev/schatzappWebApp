// SchatzApp Web call bridge: a small wrapper around the Agora Web SDK that
// the Flutter app drives through window.SchatzCall. Video is drawn into
// <div> elements the app creates; their ids are passed to attach().
(function () {
  'use strict';

  var sdkPromise = null;
  function loadSdk(src) {
    if (window.AgoraRTC) return Promise.resolve(window.AgoraRTC);
    if (sdkPromise) return sdkPromise;
    sdkPromise = new Promise(function (resolve, reject) {
      var s = document.createElement('script');
      s.src = src;
      s.async = true;
      s.onload = function () {
        if (window.AgoraRTC) {
          try { window.AgoraRTC.setLogLevel(3); } catch (e) {}
          resolve(window.AgoraRTC);
        } else {
          reject(new Error('Agora did not load'));
        }
      };
      s.onerror = function () {
        sdkPromise = null;
        reject(new Error('Could not load the call engine'));
      };
      document.head.appendChild(s);
    });
    return sdkPromise;
  }

  var state = {
    client: null,
    mic: null,
    cam: null,
    screen: null,
    remotes: {},      // uid -> { video, audio, hasVideo }
    slots: {},        // 'local' | 'remote:<uid>' | 'remote' -> element id
    onEvent: null,
  };

  function emit(type, data) {
    if (state.onEvent) {
      try { state.onEvent(JSON.stringify(Object.assign({ type: type }, data || {}))); } catch (e) {}
    }
  }

  function el(id) { return id ? document.getElementById(id) : null; }

  function playLocal() {
    var track = state.screen || state.cam;
    var node = el(state.slots.local);
    if (track && node) {
      try { track.play(node, { fit: 'cover', mirror: !state.screen }); } catch (e) {}
    }
  }

  function playRemote(uid) {
    var r = state.remotes[uid];
    if (!r || !r.video) return;
    var node = el(state.slots['remote:' + uid]) || el(state.slots.remote);
    if (node) {
      try { r.video.play(node, { fit: 'contain' }); } catch (e) {}
    }
  }

  function remoteList() {
    return Object.keys(state.remotes).map(function (k) {
      var r = state.remotes[k];
      return { uid: Number(k), hasVideo: !!r.video, hasAudio: !!r.audio };
    });
  }

  // Simple tones with WebAudio (no files): ringtone and ringback.
  var tone = { ctx: null, timer: null };
  function stopTone() {
    if (tone.timer) { clearInterval(tone.timer); tone.timer = null; }
  }
  function beep(freqs, ms) {
    try {
      tone.ctx = tone.ctx || new (window.AudioContext || window.webkitAudioContext)();
      var ctx = tone.ctx;
      var gain = ctx.createGain();
      gain.gain.value = 0.08;
      gain.connect(ctx.destination);
      freqs.forEach(function (f) {
        var o = ctx.createOscillator();
        o.frequency.value = f;
        o.connect(gain);
        o.start();
        o.stop(ctx.currentTime + ms / 1000);
      });
    } catch (e) {}
  }

  window.SchatzCall = {
    setListener: function (fn) { state.onEvent = fn; },

    tone: function (kind) {
      stopTone();
      if (kind === 'ring') {
        var ring = function () { beep([660, 880], 350); setTimeout(function () { beep([660, 880], 350); }, 450); };
        ring();
        tone.timer = setInterval(ring, 2600);
      } else if (kind === 'ringback') {
        var back = function () { beep([440, 480], 1200); };
        back();
        tone.timer = setInterval(back, 4000);
      }
    },

    // Resolves to '' on success, or an error message.
    join: function (sdkUrl, appId, channel, token, uid, video) {
      return loadSdk(sdkUrl).then(function (AgoraRTC) {
        var client = AgoraRTC.createClient({ mode: 'rtc', codec: 'vp8' });
        state.client = client;

        client.on('user-published', function (user, mediaType) {
          client.subscribe(user, mediaType).then(function () {
            var r = state.remotes[user.uid] || (state.remotes[user.uid] = {});
            if (mediaType === 'video') {
              r.video = user.videoTrack;
              playRemote(user.uid);
            } else if (mediaType === 'audio') {
              r.audio = user.audioTrack;
              try { user.audioTrack.play(); } catch (e) {}
            }
            emit('remotes', { list: remoteList() });
          }).catch(function () {});
        });
        client.on('user-unpublished', function (user, mediaType) {
          var r = state.remotes[user.uid];
          if (r) {
            if (mediaType === 'video') r.video = null;
            if (mediaType === 'audio') r.audio = null;
          }
          emit('remotes', { list: remoteList() });
        });
        client.on('user-joined', function (user) {
          state.remotes[user.uid] = state.remotes[user.uid] || {};
          emit('remotes', { list: remoteList() });
        });
        client.on('user-left', function (user) {
          delete state.remotes[user.uid];
          emit('remotes', { list: remoteList() });
          emit('user-left', { uid: user.uid });
        });
        client.on('connection-state-change', function (cur) {
          emit('connection', { state: cur });
        });

        return client.join(appId, channel, token || null, uid).then(function () {
          return AgoraRTC.createMicrophoneAudioTrack().catch(function (e) {
            throw new Error('Microphone access is blocked. Allow it in your browser and try again.');
          });
        }).then(function (mic) {
          state.mic = mic;
          if (!video) return null;
          return AgoraRTC.createCameraVideoTrack({ encoderConfig: '720p_1' }).catch(function () {
            emit('notice', { text: 'Camera is blocked or busy, so the call continues with voice.' });
            return null;
          });
        }).then(function (cam) {
          state.cam = cam;
          var tracks = [state.mic];
          if (cam) tracks.push(cam);
          playLocal();
          return client.publish(tracks);
        }).then(function () {
          emit('joined', { camera: !!state.cam });
          return '';
        });
      }).catch(function (e) {
        return (e && e.message) ? e.message : 'Could not connect the call.';
      });
    },

    attach: function (slot, elementId) {
      state.slots[slot] = elementId;
      if (slot === 'local') playLocal();
      else if (slot === 'remote') Object.keys(state.remotes).forEach(playRemote);
      else if (slot.indexOf('remote:') === 0) playRemote(slot.substring(7));
    },

    setMic: function (on) {
      if (state.mic) state.mic.setEnabled(!!on);
    },

    // Turns the camera on or off (creates it the first time).
    setCamera: function (on) {
      var client = state.client;
      if (!client || !window.AgoraRTC) return Promise.resolve('Not connected');
      if (on) {
        if (state.screen) return Promise.resolve('Stop sharing your screen first.');
        var p = state.cam
          ? state.cam.setEnabled(true).then(function () { return client.publish([state.cam]); })
          : window.AgoraRTC.createCameraVideoTrack({ encoderConfig: '720p_1' }).then(function (cam) {
              state.cam = cam;
              return client.publish([cam]);
            });
        return p.then(function () { playLocal(); return ''; })
          .catch(function () { return 'Camera is blocked or busy.'; });
      }
      if (!state.cam) return Promise.resolve('');
      return client.unpublish([state.cam]).catch(function () {}).then(function () {
        state.cam.close();
        state.cam = null;
        return '';
      });
    },

    // Shares the screen in place of the camera (one video per person).
    startScreen: function () {
      var client = state.client;
      if (!client || !window.AgoraRTC) return Promise.resolve('Not connected');
      return window.AgoraRTC.createScreenVideoTrack({ encoderConfig: '1080p_1' }, 'disable')
        .then(function (screen) {
          var before = state.cam ? client.unpublish([state.cam]) : Promise.resolve();
          return before.then(function () {
            state.screen = screen;
            screen.on('track-ended', function () {
              window.SchatzCall.stopScreen();
              emit('screen-ended', {});
            });
            return client.publish([screen]);
          });
        })
        .then(function () { playLocal(); return ''; })
        .catch(function (e) {
          var msg = (e && e.message) || '';
          if (/denied|NotAllowed|PERMISSION/i.test(msg)) return 'cancelled';
          return 'Could not share your screen.';
        });
    },

    stopScreen: function () {
      var client = state.client;
      var screen = state.screen;
      if (!client || !screen) return Promise.resolve('');
      state.screen = null;
      return client.unpublish([screen]).catch(function () {}).then(function () {
        screen.close();
        if (state.cam) return client.publish([state.cam]).catch(function () {});
      }).then(function () { playLocal(); return ''; });
    },

    leave: function () {
      stopTone();
      var client = state.client;
      ['mic', 'cam', 'screen'].forEach(function (k) {
        if (state[k]) { try { state[k].close(); } catch (e) {} state[k] = null; }
      });
      state.remotes = {};
      state.slots = {};
      state.client = null;
      return client ? client.leave().catch(function () {}) : Promise.resolve();
    },
  };
})();
