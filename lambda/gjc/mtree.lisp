;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp; Package: Macsyma -*- ;;;;;;;;;;;;;;;;;;;
;;;     (c) Copyright 1981 Massachusetts Institute of Technology         ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(macsyma-module mtree)

;;; A general macsyma tree walker.

;;; It is cleaner to have the flags and handlers passed as arguments
;;; to the function instead of having them be special variables.
;;; In maclisp (NIL?) this also happens to win big, because the arguments
;;; merely stay in registers.


(DEFMFUN MTREE-SUBST (FORM CAR-FLAG MOP-FLAG SUBST-ER)
  (COND ((ATOM FORM)
          (FUNCALL SUBST-ER FORM MOP-FLAG))
        (CAR-FLAG
         (COND (($RATP FORM)
                 (LET* ((DISREP ($RATDISREP FORM))
                         (SUB (MTREE-SUBST DISREP T MOP-FLAG SUBST-ER)))
                   (COND ((EQ DISREP SUB) FORM)
                         (T ($RAT SUB)))))
               ((ATOM (CAR FORM))
                 (MERROR "Illegal expression being walked."))
               (T
                 (LET ((CDR-VALUE (MTREE-SUBST (CDR FORM)
                                               NIL MOP-FLAG SUBST-ER))
                        (CAAR-VALUE (MTREE-SUBST (CAAR FORM)
                                                 T T SUBST-ER)))
                   (COND ((AND (EQ CDR-VALUE (CDR FORM))
                               (EQ (CAAR FORM) CAAR-VALUE))
                           FORM)
                         ;; cannonicalize the operator.
                         ((AND (LEGAL-LAMBDA CAAR-VALUE)
                               $SUBLIS_APPLY_LAMBDA)
                           `((,CAAR-VALUE
                               ,@(COND ((MEMQ 'ARRAY (CAR FORM)) '(ARRAY))
                                       (T NIL)))
                              ,@CDR-VALUE))
                         (T
                           `((MQAPPLY
                               ,@(COND ((MEMQ 'ARRAY (CAR FORM)) '(ARRAY))
                                       (T NIL)))
                              ,CAAR-VALUE
                              ,@CDR-VALUE)))))))
        (T
          (LET ((CAR-VALUE (MTREE-SUBST (CAR FORM) T MOP-FLAG SUBST-ER))
                 (CDR-VALUE (MTREE-SUBST (CDR FORM) NIL MOP-FLAG SUBST-ER)))
            (COND ((AND (EQ (CAR FORM) CAR-VALUE)
                        (EQ (CDR FORM) CDR-VALUE))
                    FORM)
                  (T
                    (CONS CAR-VALUE CDR-VALUE)))))))

(DEFUN LEGAL-LAMBDA (X)
  (COND ((ATOM X) NIL)
        ((ATOM (CAR X))
          (EQ (CAR X) 'LAMBDA))
        (T
          (EQ (CAAR X) 'LAMBDA))))

(DEFUN ($APPLY_NOUNS FOOBAR) (ATOM MOP-FLAG)
  (COND (MOP-FLAG
          (LET ((TEMP (GET ATOM '$APPLY_NOUNS)))
            (COND (TEMP TEMP)
                  ((SETQ TEMP (GET ATOM 'NOUN))
                   ;; the reason I do this instead of
                   ;; applying it now is that the simplifier
                   ;; has to walk the tree anyway, and this
                   ;; way we avoid funargiez.
                   (PUTPROP ATOM
                            `((LAMBDA) ((MLIST) ((MLIST) $$L))
                                       (($APPLY) ((MQUOTE) ,TEMP)
                                                 $$L))
                            '$APPLY_NOUNS))
                  (T ATOM))))
        (T ATOM)))

(DEFMFUN $APPLY_NOUNS (EXP)
  (LET (($SUBLIS_APPLY_LAMBDA T))
       (MTREE-SUBST EXP T NIL (GET '$APPLY_NOUNS 'FOOBAR))))
