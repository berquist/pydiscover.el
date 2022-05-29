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

;; (ert-deftest test-get-python-version-from-env-structure ()
;;   (should (equal (get-python-version-from-env-structure))))

(provide 'pydiscover-test)
