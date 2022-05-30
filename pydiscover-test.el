(require 'ert)
(require 'pydiscover)

(ert-deftest test-raw-parse-candidates ()
  (should (equal (raw-parse-candidates '())
                 nil))
  (should (equal (raw-parse-candidates '("python"))
                 '(("python"))))
  (should (equal (raw-parse-candidates '("python2"))
                 '(("python2" "2"))))
  (should (equal (raw-parse-candidates '("python3"))
                 '(("python3" "3"))))
  (should (equal (raw-parse-candidates '("python3.9"))
                 '(("python3.9" "3.9" ".9"))))
  (should (equal (raw-parse-candidates '("python3.9" "python3.8"))
                 '(("python3.9" "3.9" ".9")
                   ("python3.8" "3.8" ".8"))))
  (should (equal (raw-parse-candidates '("python3" "python3"))
                 '(("python3" "3")
                   ("python3" "3"))))
  (should (equal (raw-parse-candidates '("python3" "python2" "python3" "python3.9" "python2.7" "python" "python3.2"))
                 '(("python3" "3")
                   ("python2" "2")
                   ("python3" "3")
                   ("python3.9" "3.9" ".9")
                   ("python2.7" "2.7" ".7")
                   ("python")
                   ("python3.2" "3.2" ".2")))))

(ert-deftest test-parse-candidates ()
  (should (equal (parse-candidates nil)
                 nil))
  (should (equal (parse-candidates '(("python")))
                 (list (cons nil 0))))
  (should (equal (parse-candidates '(("python2" "2")))
                 (list (cons "2" 0))))
  (should (equal (parse-candidates '(("python3" "3")))
                 (list (cons "3" 0))))
  (should (equal (parse-candidates '(("python3.9" "3.9" ".9")
                                     ("python3.8" "3.8" ".8")))
                 (list (cons "3.9" 0)
                       (cons "3.8" 1))))
  (should (equal (parse-candidates '(("python3" "3")
                                     ("python2" "2")
                                     ("python3" "3")
                                     ("python3.9" "3.9" ".9")
                                     ("python2.7" "2.7" ".7")
                                     ("python")
                                     ("python3.2" "3.2" ".2")))
                 (list (cons "3" 0)
                       (cons "2" 1)
                       (cons "3" 2)
                       (cons "3.9" 3)
                       (cons "2.7" 4)
                       (cons nil 5)
                       (cons "3.2" 6)))))

(ert-deftest test-make-entries ()
  (should (equal (make-entries nil)
                 nil))
  (should (equal (make-entries (list (cons "2" 0)))
                 (list (list "2" nil 0))))
  (should (equal (make-entries (list (cons "3.9" 0)
                                     (cons "3.8" 1)))
                 (list (list "3" "9" 0)
                       (list "3" "8" 1))))
  (should (equal (make-entries (list (cons "3" 0)
                                     (cons "2" 1)
                                     (cons "3" 2)
                                     (cons "3.9" 3)
                                     (cons "2.7" 4)
                                     (cons nil 5)
                                     (cons "3.2" 6)))
                 (list (list "3" nil 0)
                       (list "2" nil 1)
                       (list "3" nil 2)
                       (list "3" "9" 3)
                       (list "2" "7" 4)
                       (list nil nil 5)
                       (list "3" "2" 6)))))

(ert-deftest test-group-by ()
  (should (equal (group-by nil)
                 nil))
  (should (equal (group-by '())
                 nil))
  (should (equal (group-by (list (list nil nil 0)))
                 (list (list nil
                             (list nil nil 0)))))
  (should (equal (group-by (list (list "3" nil 0)
                                 (list "2" nil 1)
                                 (list "3" nil 2)
                                 (list "3" "9" 3)
                                 (list "2" "7" 4)
                                 (list nil nil 5)
                                 (list "3" "2" 6)))
                 (list (list "3"
                             (list "3" nil 0)
                             (list "3" nil 2)
                             (list "3" "9" 3)
                             (list "3" "2" 6))
                       (list "2"
                             (list "2" nil 1)
                             (list "2" "7" 4))
                       (list nil
                             (list nil nil 5))))))

(ert-deftest test-minor-ver-comp ()
  (should (equal (minor-ver-comp "3" "2") t))
  (should (equal (minor-ver-comp "2" "3") nil))
  (should (equal (minor-ver-comp "3" nil) t))
  (should (equal (minor-ver-comp nil "3") nil))
  (should (equal (minor-ver-comp nil nil) nil)))

(ert-deftest test-sorted-groups ()
  (should (equal (sorted-groups '(("3"
                                   ("3" nil 0)
                                   ("3" nil 2)
                                   ("3" "9" 3)
                                   ("3" "2" 6))
                                  ("2"
                                   ("2" nil 1)
                                   ("2" "7" 4))
                                  (nil
                                   (nil nil 5))))
                 '((("3" "9" 3)
                    ("3" "2" 6)
                    ("3" nil 0)
                    ("3" nil 2))
                   (("2" "7" 4)
                    ("2" nil 1))
                   ((nil nil 5))))))

;; (ert-deftest test-get-best-python-interpreters-from-candidates ()
;;   (should (equal (get-best-python-interpreters-from-candidates '("python" "python3" "python3.9")) '("python3.9")))
;;   (should (equal (get-best-python-interpreters-from-candidates '("python" "python3")) '("python3")))
;;   (should (equal (get-best-python-interpreters-from-candidates '("python3" "python3")) '("python3")))
;;   (should (equal (get-best-python-interpreters-from-candidates '("python")) '("python")))
;;   ;; TODO This fails because we currently only take the single best.
;;   (should (equal (get-best-python-interpreters-from-candidates '("python3.9" "python3.8" "python")) '("python3.9" "python3.8")))
;;   ;; TODO This fails for the above reason.
;;   (should (equal (get-best-python-interpreters-from-candidates
;;                   '("/usr/bin/python"
;;                     "/usr/bin/python2"
;;                     "/usr/bin/python2.7"
;;                     "/usr/bin/python3"
;;                     "/usr/bin/python3.4"
;;                     "/usr/bin/python3.5"
;;                     "/usr/bin/python3.6"
;;                     "/usr/bin/python3.7"
;;                     "/usr/bin/python3.8"
;;                     "/usr/bin/python3.9"))
;;                  '("/usr/bin/python2.7"
;;                    "/usr/bin/python3.4"
;;                    "/usr/bin/python3.5"
;;                    "/usr/bin/python3.6"
;;                    "/usr/bin/python3.7"
;;                    "/usr/bin/python3.8"
;;                    "/usr/bin/python3.9")))
;;   ;; TODO This will fail if you only consider the length of the filename as
;;   ;; what determines the "best" interpreter.
;;   (should (equal (get-best-python-interpreters-from-candidates
;;                   '("/usr/bin/python"
;;                     "/usr/bin/python2"
;;                     "/usr/bin/python3"
;;                     "/usr/bin/python3.4"
;;                     "/usr/bin/python3.5"
;;                     "/usr/bin/python3.6"
;;                     "/usr/bin/python3.7"
;;                     "/usr/bin/python3.8"
;;                     "/usr/bin/python3.9"))
;;                  '("/usr/bin/python2"
;;                    "/usr/bin/python3.4"
;;                    "/usr/bin/python3.5"
;;                    "/usr/bin/python3.6"
;;                    "/usr/bin/python3.7"
;;                    "/usr/bin/python3.8"
;;                    "/usr/bin/python3.9"))))

;; FIXME Everything below here depends on running local to my development machine.

(ert-deftest test-get-env-basedir-from-interpreter-path/venv ()
  (should (equal (get-env-basedir-from-interpreter-path "/home/eric/data/virtualenvs/autodiff/bin/python")
                 "/home/eric/data/virtualenvs/autodiff"))
  (should (equal (get-env-basedir-from-interpreter-path "/home/eric/data/virtualenvs/cclib_custom/bin/python3.8")
                 "/home/eric/data/virtualenvs/cclib_custom")))

(ert-deftest test-get-env-basedir-from-interpreter-path/conda ()
  (should (equal (get-env-basedir-from-interpreter-path "/home/eric/.julia/conda/3/bin/python3.8")
                 "/home/eric/.julia/conda/3")))

(ert-deftest test-get-env-basedir-from-interpreter-path/pyenv ()
  (should (equal (get-env-basedir-from-interpreter-path "/home/eric/.pyenv/versions/pypy3.6-7.3.1/bin/pypy3")
                 "/home/eric/.pyenv/versions/pypy3.6-7.3.1")))

(ert-deftest test-get-env-basedir-from-interpreter-path/conda-in-pyenv ()
  (should (equal (get-env-basedir-from-interpreter-path "/home/eric/.pyenv/versions/miniconda3-4.7.12/envs/pyresponse_37/bin/python3.7")
                 "/home/eric/.pyenv/versions/miniconda3-4.7.12/envs/pyresponse_37")))

(ert-deftest test-detect-env-type-from-basedir/system ()
  (should (equal (detect-env-type-from-basedir "/usr")
                 'system)))

(ert-deftest test-detect-env-type-from-basedir/venv ()
  (should (equal (detect-env-type-from-basedir "/home/eric/data/virtualenvs/autodiff")
                 'venv)))

(ert-deftest test-detect-env-type-from-basedir/conda ()
  (should (equal (detect-env-type-from-basedir "/home/eric/.julia/conda/3")
                 'conda)))

(ert-deftest test-detect-env-type-from-basedir/pyenv ()
  (should (equal (detect-env-type-from-basedir "/home/eric/.pyenv/versions/pypy3.6-7.3.1")
                 'pyenv)))

(ert-deftest test-detect-env-type-from-basedir/conda-in-pyenv ()
  (should (equal (detect-env-type-from-basedir "/home/eric/.pyenv/versions/miniconda3-4.7.12/envs/pyresponse_37")
                 'conda-in-pyenv)))

(ert-deftest test-get-python-version-from-env-structure-by-type/system ()
  (should (equal (get-python-version-from-env-structure-by-type "/usr/bin/python3.10" 'system)
                 "3.10.4")))

;; (ert-deftest test-get-python-version-from-executing-interpreter/system ()
;;   (should (equal (get-python-version-from-executing-interpreter "/usr/bin/python3.10")
;;                  "3.10.4"))
;;   (should (equal (get-python-version-from-executing-interpreter "/usr/bin/python2.7")
;;                  "2.7.18")))

(ert-deftest test-get-python-version-from-env-structure/system ()
  (should (equal (get-python-version-from-env-structure "/usr/bin/python3.10")
                 "3.10.4"))
  (should (equal (get-python-version-from-env-structure "/usr/bin/python2.7")
                 "2.7.18"))
  (should (equal (get-python-version-from-env-structure "/usr/bin/python")
                 "3.10.4")))

;; (ert-deftest test-get-python-version-from-executing-interpreter/venv ()
;;   (should (equal (get-python-version-from-executing-interpreter "/home/eric/data/virtualenvs/autodiff/bin/python")
;;                  "3.10.4"))
;;   (should (equal (get-python-version-from-executing-interpreter "/home/eric/data/virtualenvs/cclib_custom/bin/python3.8")
;;                  "3.10.4")))

(ert-deftest test-get-python-version-from-env-structure/venv ()
  (should (equal (get-python-version-from-env-structure "/home/eric/data/virtualenvs/autodiff/bin/python")
                 "3.10.4"))
  (should (equal (get-python-version-from-env-structure "/home/eric/data/virtualenvs/cclib_custom/bin/python3.8")
                 "3.10.4")))

;; (ert-deftest test-get-python-version-from-executing-interpreter/conda ()
;;   (should (equal (get-python-version-from-executing-interpreter "/home/eric/.julia/conda/3/bin/python3.8")
;;                  "3.8.5")))

(ert-deftest test-get-python-version-from-env-structure/conda ()
  (should (equal (get-python-version-from-env-structure "/home/eric/.julia/conda/3/bin/python3.8")
                 "3.8.5")))

;; (ert-deftest test-get-python-version-from-executing-interpreter/pyenv ()
;;   (should (equal (get-python-version-from-executing-interpreter "/home/eric/.pyenv/versions/pypy3.6-7.3.1/bin/pypy3")
;;                  "3.6.9")))

(ert-deftest test-get-python-version-from-env-structure/pyenv ()
  (should (equal (get-python-version-from-env-structure "/home/eric/.pyenv/versions/3.7.5/bin/python")
                 "3.7.5"))
  ;; TODO pypy
  ;; (should (equal (get-python-version-from-env-structure "/home/eric/.pyenv/versions/pypy3.6-7.3.1/bin/pypy3")
  ;;                "3.6.9"))
  )

;; (ert-deftest test-get-python-version-from-executing-interpreter/conda-in-pyenv ()
;;   (should (equal (get-python-version-from-executing-interpreter "/home/eric/.pyenv/versions/miniconda3-4.7.12/envs/pyresponse_37/bin/python3.7")
;;                  "3.7.12")))

(ert-deftest test-get-python-version-from-env-structure/conda-in-pyenv ()
  (should (equal (get-python-version-from-env-structure "/home/eric/.pyenv/versions/miniconda3-4.7.12/envs/pyresponse_37/bin/python3.7")
                 "3.7.12")))

(ert-deftest test-get-env-basedir-from-interpreter-path/system ()
  (should (equal (get-env-basedir-from-interpreter-path "/usr/bin/python3.10")
                 "/usr"))
  (should (equal (get-env-basedir-from-interpreter-path "/usr/bin/python")
                 "/usr")))

(provide 'pydiscover-test)
