;;; pydiscover.el --- Discover all possible Python environments on your system -*- lexical-binding: t; -*-
;;
;;; Copyright (C) 2021  Free Software Foundation, Inc.
;;
;; Author: Eric Berquist <eric.berquist@gmail.com>
;; Version: 0.0.1
;; Keywords: extensions
;; URL: 
;; Package-Requires: ((emacs "24"))
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
;;  - system installs (TODO)
;;  - virtualenv / venv (TODO)
;;  - pipenv (TODO)
;;  - pyenv (TODO)
;;  - conda (TODO)

;;; Code:

(defcustom pydiscover-sep ":"
  "Display separator")

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
  "Names to ignore in the virtualenvwrapper root (WORKON_HOME)")

(defun get-candidate-python-interpreters (dir)
  "Find all candidate `pythonX.Y' interpreters in a directory."
  (directory-files
   dir
   t
   "^python\\([[:digit:]]\\(\.[[:digit:]]\\)?\\)?$"))

(defun get-path-components ()
  (delete-dups (split-string (getenv "PATH") path-separator)))

(defun filter-pyenv-shim-dirs (dirs)
  "Remove all pyenv shim directories from `dirs'."
  (seq-filter
   '(lambda (dir)
      ;; TODO switch to "begins with PYENV_ROOT"
     (not (string= (file-name-base dir) "shims")))
   dirs))

(defun get-candidate-python-interpreters-in-path ()
  "Find all candidate `pythonX.Y' interpreters in the $PATH.

This is used to discover system directories.

TODO this doesn't filter out if a conda env is already on the
path.
"
  (mapcan
   'get-candidate-python-interpreters
   (filter-pyenv-shim-dirs (get-path-components))))

(defun get-system-dirs ()
  (delete-dups
   (cl-map
    'list
    (lambda (interp)
      (expand-file-name
       (string-join `(,(file-name-directory interp) ".."))))
    (get-candidate-python-interpreters-in-path))))

(defun get-virtualenvwrapper-dir ()
  "Get the base directory containing venvs for virtualenvwrapper.

If one doesn't exist, returns nil."
  (getenv "WORKON_HOME"))

(defun get-virtualenvwrapper-paths ()
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

(defun slurp (filename)
  "https://stackoverflow.com/a/20747279/"
  (with-temp-buffer
      (insert-file-contents-literally filename)
    (buffer-string)))

(defun slurp-lines (filename)
  (split-string (slurp filename) "\n"))

(defun read-conda-environments-file ()
  (let ((conda-environments-filename
          (expand-file-name "~/.conda/environments.txt")))
    (if (file-exists-p conda-environments-filename)
        (slurp-lines conda-environments-filename))))

;; TODO
(defun detect-env-type (dir)
  "Given the base directory of an environment, figure out what kind of environment it is."
  (if (file-exists-p dir)
      (cond
        (t 'system))))

(defun make-record-from-dir (dir &optional env-type)
  `(:env-type ,(if (not (null env-type)) env-type (detect-env-type dir))
    :env-name ,(file-name-nondirectory dir)
    :env-full-base-path ,dir))

(defun get-virtualenvwrapper-environments ()
  "Get records for all virtualenvwrapper environments."
  (let ((virtualenvwrapper-dir (get-virtualenvwrapper-dir)))
    (if virtualenvwrapper-dir
        (cl-map 'list
                (lambda (dir) (make-record-from-dir dir 'virtualenvwrapper))
                (get-virtualenvwrapper-paths)))))

(defun get-pyenv-environments ()
  "Get records for all pyenv environments."
  (let ((pyenv-dir (get-pyenv-dir)))
    (if pyenv-dir
        (cl-map 'list
                (lambda (dir) (make-record-from-dir dir 'pyenv))
                (get-pyenv-versions pyenv-dir)))))

(defun get-conda-environments ()
  "Get records for all conda environments."
  (let ((conda-environment-dirs (read-conda-environments-file)))
    (if conda-environment-dirs
        (cl-map 'list
                (lambda (dir) (make-record-from-dir dir 'conda))
                conda-environment-dirs))))

(defun get-base-directories ()
  "Get records for all discovered environments."
  (cl-concatenate
   'list
   (get-virtualenvwrapper-environments)
   (get-pyenv-environments)
   (get-conda-environments)))

(defun list-base-directories ()
  (interactive)
  (with-output-to-temp-buffer
    "*pydiscover*"
    (princ
     (string-join
      (cl-map 'list
              (lambda (dir)
                (format "%s%s%s"
                        (plist-get dir :env-type)
                        pydiscover-sep
                        (plist-get dir :env-name)))
              (get-base-directories))
      "\n"))))

;;;###autoload
;; TODO: Entry-function goes here


(provide 'pydiscover)

;;; pydiscover.el ends here
