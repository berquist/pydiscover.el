(require 'ert)
(require 'pydiscover)

(ert-deftest test-get-best-python-interpreters-from-candidates ()
  (should (equal (get-best-python-interpreters-from-candidates '("python" "python3" "python3.9")) '("python3.9")))
  (should (equal (get-best-python-interpreters-from-candidates '("python" "python3")) '("python3")))
  (should (equal (get-best-python-interpreters-from-candidates '("python")) '("python")))
  ;; TODO This fails because we currently only take the single best.
  (should (equal (get-best-python-interpreters-from-candidates '("python3.9" "python3.8" "python")) '("python3.9" "python3.8")))
  ;; TODO This fails for the above reason.
  (should (equal (get-best-python-interpreters-from-candidates
                  '("/usr/bin/python"
                    "/usr/bin/python2"
                    "/usr/bin/python2.7"
                    "/usr/bin/python3"
                    "/usr/bin/python3.4"
                    "/usr/bin/python3.5"
                    "/usr/bin/python3.6"
                    "/usr/bin/python3.7"
                    "/usr/bin/python3.8"
                    "/usr/bin/python3.9"))
                 '("/usr/bin/python2.7"
                   "/usr/bin/python3.4"
                   "/usr/bin/python3.5"
                   "/usr/bin/python3.6"
                   "/usr/bin/python3.7"
                   "/usr/bin/python3.8"
                   "/usr/bin/python3.9")))
  ;; TODO This will fail if you only consider the length of the filename as
  ;; what determines the "best" interpreter.
  (should (equal (get-best-python-interpreters-from-candidates
                  '("/usr/bin/python"
                    "/usr/bin/python2"
                    "/usr/bin/python3"
                    "/usr/bin/python3.4"
                    "/usr/bin/python3.5"
                    "/usr/bin/python3.6"
                    "/usr/bin/python3.7"
                    "/usr/bin/python3.8"
                    "/usr/bin/python3.9"))
                 '("/usr/bin/python2"
                   "/usr/bin/python3.4"
                   "/usr/bin/python3.5"
                   "/usr/bin/python3.6"
                   "/usr/bin/python3.7"
                   "/usr/bin/python3.8"
                   "/usr/bin/python3.9"))))

(provide 'pydiscover-test)
