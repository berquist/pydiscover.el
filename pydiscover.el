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
;;  - conda (TODO)
;;  - pyenv (TODO)

;;; Code:


;; WORKON_HOME
;; ANACONDA_HOME


(defun get-candidate-python-interpreters (dir)
  "Find all candidate `pythonX.Y' interpreters in a directory."
  (directory-files
   dir
   t
   "^python\\([[:digit:]]\\(\.[[:digit:]]\\)?\\)?$"))


(defun get-candidiate-python-interpreters-in-path ()
  "Find all candidate `pythonX.Y' interpreters in the $PATH."
  (mapcan
   'get-candidate-python-interpreters
   (split-string (getenv "PATH") path-separator)))


(defun get-pyenv-dir ()
  "Figure out the base directory containing a pyenv install."
  (let ((pyenv-dir-user-1 (getenv "PYENV_ROOT"))
        (pyenv-dir-user-2 (getenv "PYENV"))
        (pyenv-dir-win "~/.pyenv/pyenv-win")
        (pyenv-dir-nix "~/.pyenv"))
    (cond
      ((and (not (null pyenv-dir-user-1))
            (file-directory-p pyenv-dir-user-1)) pyenv-dir-user-1)
      ((and (not (null pyenv-dir-user-2))
            (file-directory-p pyenv-dir-user-2)) pyenv-dir-user-2)
      ((file-directory-p pyenv-dir-win) pyenv-dir-win)
      ((file-directory-p pyenv-dir-nix) pyenv-dir-nix)
      (t nil))))


;; TODO proper path separators
(defun get-pyenv-versions (dir)
  (directory-files
   (format "%s/versions/" dir)
   nil
   directory-files-no-dot-files-regexp))


;; TODO: Helper-functions go here (if any)


;;;###autoload
;; TODO: Entry-function goes here


(provide 'pydiscover)

;;; pydiscover.el ends here
