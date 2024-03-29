;;; pydiscover.el --- Discover all possible Python environments on your system -*- lexical-binding: t; -*-
;;
;;; Copyright (C) 2021  Free Software Foundation, Inc.
;;
;; Author: Eric Berquist <eric.berquist@gmail.com>
;; Version: 0.0.1
;; Keywords: extensions
;; URL:
;; Package-Requires: ((emacs "24") (dash "2.19.1") (f "0.20.0"))
;;
;; This file is not a part of GNU Emacs.
;;
;;
;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.
;;
;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.
;;
;;
;;; Commentary:
;;
;; It supports discovering the following kinds of Python interpreters and
;; environments:
;;  - system installs
;;  - virtualenv / venv
;;  - pipenv
;;  - pyenv
;;  - conda

;;; Code:

(require 'cl-lib)

(require 'dash)
(require 'f)

(defgroup pydiscover nil
  "Python interpreter and environment discovery and management for Emacs."
  :group 'python)

(defcustom pydiscover-sep ":"
  "Display separator"
  :type 'string
  :group 'pydiscover)

(defcustom pydiscover-virtualenvwrapper-ignore-names
  '("get_env_details"
    "initialize"
    "postactivate"
    "postdeactivate"
    "postmkproject"
    "postmkvirtualenv"
    "postrmvirtualenv"
    "preactivate"
    "predeactivate"
    "premkproject"
    "premkvirtualenv"
    "prermvirtualenv")
  "Names to ignore in the virtualenvwrapper root (WORKON_HOME)"
  :type 'list
  :group 'pydiscover)

(defconst pydiscover-python-executable-regex "^python\\([[:digit:]]\\(\.[[:digit:]]+\\)?\\)?$"
  "A regular expression for matching CPython interpreter executables.

This expects all path components to be stripped off the front.")

(defconst python-version-regex "\\([[:digit:]]+\\)\.\\([[:digit:]]+\\)\.\\([[:digit:]]+\\)\\(a\\|b\\|rc\\)?\\([[:digit:]]*\\)"
  "A regular expression for parsing Python version numbers.

Handles versions like:
   3.9.0
   3.9.0a1
   3.9.0b2
   3.9.0rc1
Does not handle versions like:
   3.9.0.final.0
   3.9.0.alpha.1
   3.9.0.beta.2
   3.9.0.candidate.1

TODO handle two digit version numbers
")

(defun get-candidate-python-interpreters (dir)
  "Find all candidate `pythonX.Y' interpreters in directory DIR."
  (directory-files
   dir
   t
   pydiscover-python-executable-regex))

(defun raw-parse-candidates (candidates)
  (mapcar (lambda (c) (s-match pydiscover-python-executable-regex (f-filename c)))
          candidates))

(defun parse-candidates (raw-parsed-candidates)
  (let ((candidate-indices (number-sequence 0 (1- (length raw-parsed-candidates)))))
    (--zip-with (cons it other)
                (mapcar (lambda (c) (nth 1 c))
                        raw-parsed-candidates)
                candidate-indices)))

(defun make-entries (parsed-candidates)
  (mapcar (lambda (it)
            (list (if (car it) (car (s-match "^[0-9]+" (car it))))
                  (if (car it) (cadr (s-match "^[0-9]+\.\\([0-9]+\\)$" (car it))))
                  (cdr it))) 
          parsed-candidates))

(defun group-by (entries)
  (--group-by (car it) entries))

(defun minor-ver-comp (v1 v2)
  (let ((i1 (if (stringp v1) (string-to-number v1) -1))
        (i2 (if (stringp v2) (string-to-number v2) -1)))
    (> i1 i2)))

(defun sorted-groups (groups)
  (mapcar (lambda (grp)
            (-sort (lambda (e1 e2) (minor-ver-comp (cadr e1) (cadr e2))) (cdr grp)))
          groups))

(defun get-best-python-interpreters-from-candidates (candidates)
  "Given a number Python interpreter CANDIDATES, return the best ones.

If the CANDIDATES contain full path information, assume that each
are in the same base directory/environment."
  ;; For each major version,
  ;; - if there is only one match, keep it,
  ;; - else, take all that contain the maximal amount of version
  ;;   information.  Since there is only one possible appearance of the
  ;;   interpreter with the major version but no minor version present, in
  ;;   practice this means that all major.minor version entries are kept,
  ;;   and if a major-only version entry exists, ignore it. This also means
  ;;   that if, for example, the only matches are "python3" and "python3.9",
  ;;   and "python3" isn't actually 3.9, that match will be lost.
  (let ((grouped-sorted-candidates (-> candidates
                                       raw-parse-candidates
                                       parse-candidates
                                       make-entries
                                       group-by
                                       sorted-groups)))
    grouped-sorted-candidates))

(defun get-path-components ()
  "Get all components of $PATH.

Duplicates are removed and elements that don't exist as
directories are filtered out."
  (seq-filter
   'f-directory-p
   (delete-dups (split-string (getenv "PATH") path-separator))))

(defun filter-pyenv-dirs (dirs)
  "Remove all pyenv directories from DIRS."
  (let ((pyenv-dir (get-pyenv-dir)))
    (if pyenv-dir
        (seq-filter
         `(lambda (dir)
            (not (string-match-p ,(regexp-quote pyenv-dir) dir)))
         dirs))))

(defun get-candidate-python-interpreters-in-path ()
  "Find all candidate `pythonX.Y' interpreters in the $PATH.

This is used to discover system directories.

TODO this doesn't filter out if a conda env is already on the
path unless that conda env is within pyenv.
"
  (mapcan
   'get-candidate-python-interpreters
   (filter-pyenv-dirs (get-path-components))))

;; (defun get-system-dirs ()
;;   "Get (base) system directories that contain Python interpreters in subdirs."
;;   (delete-dups
;;    (cl-map
;;     'list
;;     (lambda (interp)
;;       (expand-file-name
;;        (string-join `(,(file-name-directory interp) ".."))))
;;     (get-candidate-python-interpreters-in-path))))
(defun get-system-dirs ()
  '("/usr" "/usr/local"))

(defun get-interpreters-in-dirs (dirs get-realpath)
  "Get all Python interpreters in each `bin' subdir of DIRS."
  (mapcan
   (lambda (dir)
     (delete-dups
      (cl-map
       'list
       (lambda (interp)
         (if get-realpath
             (file-truename interp)
           interp))
       (get-candidate-python-interpreters (string-join `(,dir "/" "bin"))))))
   dirs))

(defun get-system-interpreters ()
  "Get all system-installed Python interpreters."
  (get-interpreters-in-dirs (get-system-dirs) t))

(defun get-virtualenvwrapper-dir ()
  "Get the base directory containing venvs for virtualenvwrapper.

If one doesn't exist, returns nil."
  (getenv "WORKON_HOME"))

(defun get-virtualenvwrapper-dirs ()
  "Get the full path to each venv under virtualenvwrapper."
  (let ((virtualenvwrapper-dir (get-virtualenvwrapper-dir)))
    (if virtualenvwrapper-dir
        (cl-map
         'list
         (lambda (envname) (format "%s/%s" virtualenvwrapper-dir envname))
         (seq-filter
          '(lambda (envname)
             (not (member envname pydiscover-virtualenvwrapper-ignore-names)))
          (directory-files virtualenvwrapper-dir nil directory-files-no-dot-files-regexp))))))

(defun get-virtualenvwrapper-interpreters ()
  "Get all virtualenvwrapper-installed Python interpreters."
  (get-interpreters-in-dirs (get-virtualenvwrapper-dirs) nil))

(defun get-pyenv-dir ()
  "Figure out the base directory containing a pyenv install.

If one doesn't exist, returns nil."
  (let ((pyenv-dir-user-1 (getenv "PYENV_ROOT"))
        (pyenv-dir-user-2 (getenv "PYENV"))
        (pyenv-dir-win (expand-file-name "~/.pyenv/pyenv-win"))
        (pyenv-dir-nix (expand-file-name "~/.pyenv")))
    (cond
     ((and (not (null pyenv-dir-user-1))
           (file-directory-p pyenv-dir-user-1))
      (expand-file-name pyenv-dir-user-1))
     ((and (not (null pyenv-dir-user-2))
           (file-directory-p pyenv-dir-user-2))
      (expand-file-name pyenv-dir-user-2))
     ((file-directory-p pyenv-dir-win) pyenv-dir-win)
     ((file-directory-p pyenv-dir-nix) pyenv-dir-nix)
     (t nil))))

;; TODO proper path separators
(defun get-pyenv-versions (dir)
  (directory-files
   (format "%s/versions/" dir)
   nil
   directory-files-no-dot-files-regexp))

(defun get-pyenv-interpreters ()
  "Get all pyenv-installed Python interpreters."
  (let ((pyenv-dir (get-pyenv-dir)))
    (get-interpreters-in-dirs
     (cl-map
      'list
      (lambda (version) (concat pyenv-dir "/versions/" version))
      (get-pyenv-versions pyenv-dir))
     t)))

(defun slurp (filename)
  "Read the contents of the text file FILENAME into a string.

https://stackoverflow.com/a/20747279/"
  (with-temp-buffer
    (insert-file-contents-literally filename)
    (buffer-string)))

(defun slurp-lines (filename)
  "Read the contents of the text file FILENAME, splitting on newlines into a list.

Blank lines are preserved."
  (split-string (slurp filename) "\n"))

(defun read-conda-environments-file ()
  (let ((conda-environments-filename
         (expand-file-name "~/.conda/environments.txt")))
    (if (file-exists-p conda-environments-filename)
        ;; Deal with a possible trailing newline.
        (seq-filter
         (lambda (line) (> (length line) 0))
         (slurp-lines conda-environments-filename)))))

(defalias 'get-conda-dirs 'read-conda-environments-file)

(defun get-conda-interpreters ()
  (get-interpreters-in-dirs (get-conda-dirs) t))

(defun get-python-version-from-conda-dir (dir)
  "Get the Python version from a conda environment base directory DIR.

Look in the DIR/conda-meta directory for the JSON entry
corresponding to the core CPython interpreter package.

TODO this won't detect a PyPy interpreter installed in the same
env as a CPython one."
  (nth 1 (s-split "-" (car (directory-files (format "%s/%s" dir "conda-meta") nil "^python-[[:digit:]]")))))

;; (setq pyenv-version-base-dirs
;;       (cl-map
;;        'list
;;        (lambda (version) (concat pyenv-dir "/versions/" version))
;;        (get-pyenv-versions pyenv-dir)))

;; (setq conda-base-dirs-in-pyenv
;;       (seq-filter
;;        (lambda (pyenv-base-dir) (is-conda-dir pyenv-base-dir))
;;        pyenv-version-base-dirs))

;; (setq conda-envs-in-pyenv
;;       (mapcan
;;        (lambda
;;          (conda-base-dir)
;;          (seq-filter
;;           (lambda
;;             (candidate-conda-env-dir)
;;             (not (string-match-p (regexp-quote ".conda_envs_dir_test") candidate-conda-env-dir)))
;;           (directory-files (concat conda-base-dir "/envs") t directory-files-no-dot-files-regexp)))
;;        conda-base-dirs-in-pyenv))

(defun is-system-dir (dir)
  "Is DIR a system directory?"
  (member dir (get-system-dirs)))

(defun is-virtualenvwrapper-dir (dir)
  "Is DIR a virtualenvwrapper directory?"
  (f-ancestor-of? (get-virtualenvwrapper-dir) dir))

(defun is-pyenv-dir (dir)
  "Is DIR a pyenv directory?"
  (string-match-p (regexp-quote (get-pyenv-dir)) dir))

(defun is-conda-dir (dir)
  "Is DIR a conda directory?"
  (directory-files dir nil "conda-meta"))

(defun is-conda-dir-inside-pyenv (dir)
  "Is DIR a conda directory inside of a pyenv directory?"
  (and (is-pyenv-dir dir)
       (is-conda-dir dir)))

(defun detect-env-type-from-basedir (dir)
  "Figure out the environment type at base directory DIR."
  (if (file-exists-p dir)
      (cond
       ((is-system-dir dir) 'system)
       ((is-virtualenvwrapper-dir dir) 'venv)
       ((is-conda-dir-inside-pyenv dir) 'conda-in-pyenv)
       ((is-pyenv-dir dir) 'pyenv)
       ((is-conda-dir dir) 'conda)
       (t nil))))

(defun get-env-basedir-from-interpreter-path (interpreter-path)
  "TODO

This assumes that the location of the interpreter is always of
the form `/path/to/basedir/bin/pythonX.Y', returning
`/path/to/basedir' (unresolved but expanded)."
  (expand-file-name (format "%s/../.." interpreter-path)))

(defun get-python-version-from-parsing-sysconfigdata (interpreter-path)
  "Get Python interpreter version by searching through sysconfigdata.

Specifically, given `/path/to/bin/pythonX.Y', search through
`/path/to/lib/pythonX.Y/*sysconfig*.py'.

INTERPRETER-PATH may be a symlink, and its true path is resolved
internally."
  (let* ((interpreter-realpath (file-truename interpreter-path))
         (path-version (cadr (s-match pydiscover-python-executable-regex (f-filename interpreter-realpath))))
         (interpreter-basedir (get-env-basedir-from-interpreter-path interpreter-realpath))
         (lib-dir (f-join interpreter-basedir "lib" (format "python%s" path-version)))
         (sysconfigdata-path (car (f-glob "*sysconfigdata*.py" lib-dir))))
    (if sysconfigdata-path
        (let ((match-components (s-match
                                 (format "Python-%s" python-version-regex)
                                 (seq-find (lambda (line) (s-matches-p "COVERAGE_INFO" line))
                                           (slurp-lines sysconfigdata-path)))))
          (s-join "." (-slice match-components 1 4)))
      ;; Fall back to the version parsed directly from the path.
      path-version)))

(defun detect-env-type-from-interpreter-path (interpreter-path)
  (detect-env-type-from-basedir (get-env-basedir-from-interpreter-path interpreter-path)))

(defun get-python-version-from-executing-interpreter (interpreter-path)
  "Get Python interpreter version by parsing 'INTERPRETER-PATH --version'."
  ;; ^Python (\d+)\.(\d+)\.(\d+)(a|b|rc)?(\d*)
  (let* ((python-version-raw-string
          (shell-command-to-string (format "%s --version" interpreter-path)))
         (python-version-full-regex (format "^[JP]ython %s" python-version-regex))
         (matches (cdr (s-match python-version-full-regex python-version-raw-string)))
         (main-version (s-join "." (-slice matches 0 3)))
         (dev-version-components (-slice matches 3)))
    (if dev-version-components
        (concat main-version (s-join "" dev-version-components))
      main-version)))

(defun get-python-version-from-env-structure-by-type (interpreter-path env-type)
  (let ((env-basedir (get-env-basedir-from-interpreter-path interpreter-path)))
    (if (file-exists-p env-basedir)
        (cond
         ((eq env-type 'system)
          (get-python-version-from-parsing-sysconfigdata interpreter-path))
         ((eq env-type 'venv)
          (get-python-version-from-parsing-sysconfigdata interpreter-path))
         ((eq env-type 'conda-in-pyenv)
          (get-python-version-from-conda-dir env-basedir))
         ((eq env-type 'pyenv)
          (get-python-version-from-parsing-sysconfigdata interpreter-path))
         ((eq env-type 'conda)
          (get-python-version-from-conda-dir env-basedir))
         (t nil)))))

(defun get-python-version-from-env-structure (interpreter-path)
  "Get Python interpreter version by looking up environment-specific information."
  (let ((env-type (detect-env-type-from-interpreter-path interpreter-path)))
    (get-python-version-from-env-structure-by-type interpreter-path env-type)))

(defun make-record-from-interpreter (interp-path &optional env-type)
  (let ((dir (expand-file-name (string-join `(,(file-name-directory interp-path) "..") "/"))))
    `(:interp-name ,(file-name-nondirectory interp-path)
      :interp-version ,(get-python-version-from-env-structure interp-path)
      :env-type ,(if (not (null env-type)) env-type (detect-env-type-from-basedir dir))
      :env-name ,(file-name-nondirectory dir)
      :inter-full-path ,interp-path
      :env-full-base-path ,dir)))

(defun make-records-from-interpreters (interpreters)
  (cl-map
   'list
   (lambda (interp-path)
     (make-record-from-interpreter interp-path))
   interpreters))

(defun get-system-records ()
  "Get records for all system \"environments\"."
  (make-records-from-interpreters (get-system-interpreters)))

(defun get-virtualenvwrapper-records ()
  "Get records for all virtualenvwrapper environments."
  (make-records-from-interpreters (get-virtualenvwrapper-interpreters)))

(defun get-pyenv-records ()
  "Get records for all pyenv environments."
  (make-records-from-interpreters (get-pyenv-interpreters)))

(defun get-conda-records ()
  "Get records for all conda environments."
  (make-records-from-interpreters (get-conda-interpreters)))

(defun get-all-records ()
  "Get records for all discovered environments."
  (cl-concatenate
   'list
   (get-system-records)
   (get-virtualenvwrapper-records)
   (get-pyenv-records)
   (get-conda-records)))

(defun list-records ()
  (interactive)
  (with-output-to-temp-buffer
      "*pydiscover*"
    (princ
     (string-join
      (cl-map 'list
              (lambda (dir)
                (format "%s%s%s%s%s%s%s"
                        (plist-get dir :env-type)
                        pydiscover-sep
                        (plist-get dir :env-name)
                        pydiscover-sep
                        (plist-get dir :interp-version)
                        pydiscover-sep
                        (plist-get dir :interp-name)))
              (get-all-records))
      "\n"))))


(provide 'pydiscover)

;;; pydiscover.el ends here
