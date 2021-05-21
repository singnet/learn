;
; utilities.scm
;
; Generic utilities.
; These do NOT assume opencog; they'll work outside of opencog.
;
; Utilites include:
; * A parallel version of the srfi-1 find function
; * A for-all-pairs function
; * A fold-over-all-pairs function
; * A debug-repl-shell tool
;
; Copyright (c) 2017, 2018 Linas Vepstas
;
; ---------------------------------------------------------------------

(use-modules (srfi srfi-1))
(use-modules (ice-9 atomic))
(use-modules (ice-9 receive))   ; for partition
(use-modules (ice-9 threads))

; ---------------------------------------------------------------------
;
(define (par-find PRED LST)
"
  par-find PRED LST

  Apply PRED to elements in LST, and return the first element for
  which PRED evaluates to #t; else return #f.

  This is similar to the srfi-1 `find` function, except that the
  processing is done in parallel, over multiple threads.
"
	; If the number of threads was just 1, then do exactly this:
	; (find PRED LST)

	(define NTHREADS 4)
	(define SLEEP-TIME 1)

	; Design issues:
	; 1) This uses sleep in a hacky manner, to poll for finished
	;    threads. This is OK for the current application but is
	;    hacky, and needs to be replaced by some semaphore.
	; 2) Guile-2.2 threads suck.  There's some kind of lock contention,
	;    somewhere, which leads to lots of thrashing, when more
	;    than 2-3 threads are run. The speedup from even 2 threads
	;    is lackluster and barely acceptable.

	; Return #t if thr is a thread, and if its still running
	(define (is-running? thr)
		(and (thread? thr) (not (thread-exited? thr))))

	; Return exit value of the thread, if its actually a thread.
	(define (get-result thr)
		(if (thread? thr) (join-thread thr) #f))

	; Convenience wrapper for srfi-1 partition
	(define (parton PRED LST)
		(receive (y n) (partition PRED LST) (list y n)))

	; thread launcher - return a list of the launched threads.
	; Note: CNT musr be equal to or smaller than (length ITM-LST)
	(define (launch ITM-LST CNT)
		(if (< 0 CNT)
			(cons
				(call-with-new-thread
					(lambda () (if (PRED (car ITM-LST)) (car ITM-LST) #f)))
				(launch (cdr ITM-LST) (- CNT 1)))
			'()))

	; Check the threads to see if any got an answer.
	; If so, return the answer.
	; If not, examine ITEMS in some threads.
	(define (check-threads THRD-LST ITEMS)
		; Partition list of threads into those that are running,
		; and those that are stopped.
		(define status (parton is-running? THRD-LST))
		(define running (car status))
		(define stopped (cadr status))

		; Did any of the stopped threads return a value
		; other than #f? If so, then return that value.
		(define found
			(find (lambda (v) (not (not v))) (map get-result stopped)))

		; Compute number of new threads to start
		(define num-to-launch
			(min (- NTHREADS (length running)) (length ITEMS)))

		; Return #t if we've looked at them all.
		(define done
			(and (= 0 num-to-launch)
				(= 0 (length running))
				(= 0 (length ITEMS))))

		; If we found a value, we are done.
		; If list is exhausted, we are done.
		; Else, launch some threads and wait.
		(if found found
			(if done #f
				(let ((thrd-lst (append! (launch ITEMS num-to-launch) running)))
					(if (= 0 num-to-launch) (sleep SLEEP-TIME))
					(check-threads thrd-lst (drop ITEMS num-to-launch)))))
	)

	(check-threads (make-list NTHREADS #f) LST)
)

; ---------------------------------------------------------------------
;
(define (for-all-unordered-pairs FUNC LST)
"
  for-all-unordered-pairs FUNC LST

  Call function FUNC on all possible unordered pairs created from LST.
  That is, given the LST of N items, create all possible pairs of items
  from this LST. There will be N(N-1)/2 such pairs.  Then call FUNC on
  each of these pairs.  This means that the runtime is O(N^2).

  The function FUNC must accept two arguments. The return value of FUNC
  is ignored.

  The return value is unspecified.
"
	(define (make-next-pair primary rest)
		(define more (cdr primary))
		(if (not (null? more))
			(if (null? rest)
				(make-next-pair more (cdr more))
				(let ((item (car primary))
						(next-item (car rest)))
					(format #t "~A ~A " (length primary) (length rest))
					(FUNC item next-item)
					(make-next-pair primary (cdr rest))))))

	(make-next-pair LST (cdr LST))
)

; ---------------------------------------------------------------------
;
(define (fold-unordered-pairs ACC FUNC LST)
"
  Call function FUNC on all possible unordered pairs created from LST.
  That is, given the LST of N items, create all possible pairs of items
  from this LST. There will be N(N-1)/2 such pairs.  Then call FUNC on
  each of these pairs.  This means that the runtime is O(N^2).

  The function FUNC must accept three arguments: the first two
  are the pair, and the last is the accumulated (folded) value.
  It must return the (modified) accumulated value.

  This returns the result of folding on these pairs.
"
	(define (make-next-pair primary rest accum)
		(define more (cdr primary))
		(if (null? more) accum
			(if (null? rest)
				(make-next-pair more (cdr more) accum)
				(let ((item (car primary))
						(next-item (car rest)))
					(format #t "~A ~A " (length primary) (length rest))
					(make-next-pair primary (cdr rest)
						(FUNC item next-item accum))
				))))

	(make-next-pair LST (cdr LST) ACC)
)

; ---------------------------------------------------------------
; ---------------------------------------------------------------
;
(define-public (make-rate-monitor)
"
  make-rate-monitor - simplistic rate monitoring utility.

  Use this to monitor the rate at which actions are being performed.
  It returns a function taking one argument: either #f or a string
  message. If called with #f, it increments a count and returns.
  If called with a message, it will print the processing rate.

  Example usage:
    (define monitor-rate (make-rate-monitor))
    (monitor-rate #f)
    (sleep 1)
    (monitor-rate #f)
    (monitor-rate \"This is progress:\")
    (monitor-rate \"Did ~A in ~A seconds rate=~5F items/sec\")
"
	(define cnt (make-atomic-box 0))
	(define start-time (- (current-time) 0.000001))

	(lambda (msg)
		(if (nil? msg)
			(atomic-inc cnt)
			(let* ((acnt (atomic-box-ref cnt))
					(elapsed (- (current-time) start-time))
					(rate (/ acnt elapsed))
				)
				(if (string-index msg #\~)
					(format #t msg acnt elapsed rate)
					(format #t "~A done=~A rate=~5f per sec\n"
						msg acnt rate)))))
)

; ---------------------------------------------------------------

(define-public (block-until-idle BUSY-FRAC)
"
  block-until-idle BUSY-FRAC - Block until CPU usage goes below BUSY-FRAC

  This function simply won't return until the CPU usage drops below
  BUSY-FRAC, which must be a number less than 1.0 and greater than
  0.03. The min value is because this function uses CPU time itself,
  and so contributes to the business of the system.
"
	(define (block cpuuse)
		(sleep 1)
		(let ((now (get-internal-run-time)))
			(if (< BUSY-FRAC (/ (- now cpuuse) 1000000000.0))
				(block now))))
	(block (get-internal-run-time))
)

; ---------------------------------------------------------------------
; Report the average time spent in GC.
(define-public report-avg-gc-cpu-time
	(let ((last-gc (gc-stats))
			(start-time (get-internal-real-time))
			(run-time (get-internal-run-time)))
		(lambda ()
			(define now (get-internal-real-time))
			(define run (get-internal-run-time))
			(define cur (gc-stats))
			(define gc-time-taken (* 1.0e-9 (- (cdar cur) (cdar last-gc))))
			(define elapsed-time (* 1.0e-9 (- now start-time)))
			(define cpu-time (* 1.0e-9 (- run run-time)))
			(define ngc (- (assoc-ref cur 'gc-times)
				(assoc-ref last-gc 'gc-times)))
			(format #t "Elapsed: ~6f secs. Rate: ~5f gc/min %cpu-GC: ~5f%  %cpu-use: ~5f%\n"
				elapsed-time
				(/ (* ngc 60) elapsed-time)
				(* 100 (/ gc-time-taken elapsed-time))
				(* 100 (/ cpu-time elapsed-time))
			)
			(set! last-gc cur)
			(set! start-time now)
			(set! run-time run))))

(set-procedure-property! report-avg-gc-cpu-time 'documentation
"
  report-avg-gc-cpu-time - Report the average time spent in GC.

  Print statistics about how much time has been spent in garbage
  collection, and how much time spent in other computational tasks.
  Resets the stats after each call, so only the stats since the
  previous call are printed.
"
)

; ---------------------------------------------------------------

(use-modules (ice-9 local-eval))
(use-modules (ice-9 readline))

(define-public (break env)
"
  break ENV - debug repl shell.

  This can be inserted into arbitrary points in scheme code, and will
  provide a debug prompt there.  Example usage:

     (define (do-stuff)
        (define x 42)
        (format #t \"starting x=~A\n\" x)
        (break (the-environment))
        (format #t \"ending x=~A\n\" x))

  At the prompt, `x` will print `42` and `(set! x 43)` will change it's
  value.

  MUST say `(use-modules (ice-9 local-eval))` to get `(the-environment)`
"
	(define (brk env num)
		(let ((input (readline "yo duude> ")))
			(unless (or (eq? '. input) (eof-object? input))
				(catch #t (lambda ()
					(define sexpr (call-with-input-string input read))
					(format #t "$~A = ~A\n" num (local-eval sexpr env)))
					(lambda (key . args)
						(format #t "Oh no, Mr. Bill: ~A ~A\n" key args)
						*unspecified*))
				(brk env (+ 1 num)))))
	(brk env 1)
)

; ---------------------------------------------------------------
