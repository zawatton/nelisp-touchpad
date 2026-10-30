;;; build.el --- Compile the Sumi touchpad tray with NeLisp -*- lexical-binding: t; -*-
(require 'cl-lib)
(setq max-lisp-eval-depth 10000 max-specpdl-size 20000)
(defconst touchpad-root (file-name-directory (or load-file-name buffer-file-name)))
(defconst touchpad-nelisp-root
  (expand-file-name (or (getenv "NELISP_ROOT") "../nelisp") touchpad-root))
(defconst touchpad-sumi-root
  (expand-file-name (or (getenv "SUMI_ROOT") "../sumi") touchpad-root))
(add-to-list 'load-path (expand-file-name "lisp" touchpad-nelisp-root))
(add-to-list 'load-path (expand-file-name "src" touchpad-nelisp-root))
(require 'nelisp-aot-compiler)
(add-to-list 'exec-path (file-name-directory (executable-find "gcc")))
(setenv "PATH" (concat (car exec-path) path-separator (getenv "PATH")))
(setenv "PKG_CONFIG_PATH"
        (or (getenv "PKG_CONFIG_PATH")
            (expand-file-name "../lib/pkgconfig"
                              (file-name-directory (executable-find "gcc")))))
(let* ((target (expand-file-name "target" touchpad-root))
       (object (expand-file-name "touchpad.o" target))
       (resource (expand-file-name "touchpad-res.o" target))
       (exe (expand-file-name "nelisp-touchpad.exe" target))
       (sumi-source (expand-file-name "backends/cairo-elisp/sumi-sprite-live.el" touchpad-sumi-root))
       (renderer (with-temp-buffer (insert-file-contents sumi-source) (read (current-buffer))))
       (color (cl-find 'apply_source_rgba (cdr renderer) :key #'cadr))
       (program (with-temp-buffer
                  (insert-file-contents (expand-file-name "src/tray.el" touchpad-root))
                  (read (current-buffer))))
       (labels '((class_name . "Fujisawa.NeLispTouchpad")
                 (mutex_name . "Local\\Fujisawa.NeLispTouchpad")
                 (restart_message . "TaskbarCreated")
                 (title . "タッチパッド") (on_label . "オンにする")
                 (off_label . "オフにする") (exit_label . "終了")
                 (settings_label . "Windowsのタッチパッド設定")
                 (settings_uri . "ms-settings:devices-touchpad")
                 (open_verb . "open")
                 (on_tip . "タッチパッド: オン — クリックでオフ")
                 (off_tip . "タッチパッド: オフ — クリックでオン")
                 (unknown_tip . "タッチパッド: 状態を取得できません")
                 (error_label . "タッチパッドを切り替えられませんでした。Windowsの設定を確認してください。"))))
  (unless color (error "Sumi apply_source_rgba is unavailable"))
  (make-directory target t)
  (with-temp-buffer
    (unless (= 0 (call-process (or (getenv "PYTHON_BIN") (executable-find "python")) nil t nil
                              (expand-file-name "tools/build-icon.py" touchpad-root)))
      (error "Application icon generation: %s" (buffer-string))))
  (let ((default-directory (expand-file-name "src" touchpad-root))
        (windres (expand-file-name "windres.exe" (file-name-directory (executable-find "gcc")))))
    (with-temp-buffer
      (unless (= 0 (call-process windres nil t nil "touchpad.rc" "-O" "coff" "-o" resource))
        (error "Manifest compilation: %s" (buffer-string)))))
  (setq program (append program (list color)
                        (mapcar (lambda (pair)
                                  (let ((bytes (concat (cdr pair) "\0")))
                                    `(data-blob ,(car pair)
                                                ,(if (cl-oddp (length bytes)) (concat bytes "\0") bytes) rodata)))
                                '((preview_env_on . "NELISP_TOUCHPAD_ICON_ON")
                                  (preview_env_off . "NELISP_TOUCHPAD_ICON_OFF")))
                        (mapcar (lambda (pair)
                                  `(data-blob ,(car pair)
                                              ,(encode-coding-string (concat (cdr pair) "\0") 'utf-16le) rodata))
                                labels)))
  ;; This program has statically known AOT frames. The interpreter-only
  ;; alignment path requires driver globals and is unsafe for GUI reentry.
  (let ((nelisp-aot-compiler--win64-dynamic-align-names nil))
    (nelisp-aot-compile-to-object program object :format 'coff))
  (let* ((flags (with-temp-buffer
                  (unless (= 0 (call-process "pkg-config" nil t nil "--libs" "cairo"))
                    (error "Cairo flags: %s" (buffer-string)))
                  (split-string (string-trim (buffer-string)) " " t)))
         (result (with-temp-buffer
                   (let ((status (apply #'call-process "gcc" nil t nil object resource
                                        (append flags (list "-luser32" "-lshell32" "-lgdi32"
                                                            "-mwindows" "-o" exe)))))
                     (unless (= 0 status) (error "Link: %s" (buffer-string)))))))
    (princ (format "TOUCHPAD-BUILD-OK %s\n" exe))))
