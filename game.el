
;; ============================================================
;;  Conwayjeva "Game of Life" (Igra života) u Emacsu
;;
;;  Ideja:
;;    - Imamo mrežu (grid) ćelija koje su žive ili mrtve.
;;    - Svaki "tick" (generacija) izračunamo novu mrežu po pravilima:
;;        1) Živa ćelija preživi ako ima 2 ili 3 živa susjeda
;;        2) Mrtva ćelija oživi ako ima točno 3 živa susjeda
;;        3) Inače umire / ostaje mrtva
;;
;;  Kontrole:
;;    SPC  -> pokreni / pauziraj
;;    n    -> jedan korak (sljedeća generacija)
;;    t    -> toggle ćeliju ispod kursora
;;    r    -> random mreža
;;    c    -> očisti mrežu
;;    q    -> izlaz
;; ============================================================

(require 'cl-lib)

;; -------------------------------
;;  POSTAVKE (kao "konfiguracija")
;; -------------------------------

(defvar-local life--old-cursor-color nil)
(defvar life-cursor-color "orange" "Boja kursora u Life modu.")


(defgroup life nil
  "Igra života u Emacsu."
  :group 'games)

(defcustom life-rows 20
  "Broj redaka mreže."
  :type 'integer
  :group 'life)

(defcustom life-cols 40
  "Broj stupaca mreže."
  :type 'integer
  :group 'life)

(defcustom life-alive-char ?#
  "Znak kojim prikazujemo živu ćeliju."
  :type 'character
  :group 'life)

(defcustom life-dead-char ?.
  "Znak kojim prikazujemo mrtvu ćeliju."
  :type 'character
  :group 'life)

(defcustom life-random-density 0.25
  "Vjerojatnost da je ćelija živa kod random punjenja."
  :type 'float
  :group 'life)

(defcustom life-tick-seconds 0.12
  "Koliko sekundi čekamo između generacija dok igra radi."
  :type 'float
  :group 'life)

(defface life-alive-face
  '((t :background "chartreuse3" :foreground "chartreuse3"))
  "Face za živu ćeliju."
  :group 'life)

(defface life-dead-face
  '((t :background "gray15" :foreground "gray15"))
  "Face za mrtvu ćeliju."
  :group 'life)

(defcustom life-cell-width 2
  "Širina jedne ćelije u znakovima (preporuka 2)."
  :type 'integer
  :group 'life)
(defface life-grid-face
  '((t :foreground "gray70"))
  "Face za linije mreže."
  :group 'life)

(defcustom life-grid-vertical ?│
  "Znak za vertikalne linije mreže."
  :type 'character
  :group 'life)

(defcustom life-grid-horizontal ?─
  "Znak za horizontalne linije mreže."
  :type 'character
  :group 'life)

(defcustom life-grid-cross ?┼
  "Znak za križanje linija mreže."
  :type 'character
  :group 'life)


(defconst life-buffer-name "*Igra života*"
  "Naziv buffera u kojem se prikazuje igra.")




;; ---------------------------------------------------------
;;  INTERNI STATE (spremamo lokalno u buffer)
;; ---------------------------------------------------------

(defvar-local life--grid nil)         ;; mreža: vektor redaka, svaki red je vektor 0/1
(defvar-local life--generation 0)     ;; trenutna generacija
(defvar-local life--running nil)      ;; radi li automatski (timer) ili je pauza
(defvar-local life--timer nil)        ;; Emacs timer za automatsko "tickanje"

;; Da nam kursor ostane na istoj ćeliji nakon renderiranja
(defvar-local life--cursor-r 0)
(defvar-local life--cursor-c 0)




;; ============================================================
;;  1) FUNKCIJE ZA MREŽU (grid)
;; ============================================================

(defun life--make-empty-grid ()
  "Kreiraj praznu mrežu (sve mrtvo)."
  (let ((g (make-vector life-rows nil)))
    (dotimes (r life-rows g)
      (aset g r (make-vector life-cols 0)))))

(defun life--make-random-grid (&optional density)
  "Kreiraj random mrežu (svaka ćelija živa s vjerojatnošću DENSITY).

Napomena:
U Emacs Lispu ne može ići (&optional (density ...)) kao u Common Lispu,
pa default vrijednost rješavamo ručno preko (or density life-random-density)."
  (let* ((density (or density life-random-density))
         (g (life--make-empty-grid)))
    (dotimes (r life-rows g)
      (dotimes (c life-cols)
        (aset (aref g r) c (if (< (random 1.0) density) 1 0))))))

(defun life--in-bounds-p (r c)
  "Provjeri je li koordinata (R,C) unutar mreže."
  (and (<= 0 r) (< r life-rows)
       (<= 0 c) (< c life-cols)))

(defun life--get-cell (grid r c)
  "Vrati 1 ako je ćelija živa, 0 ako je mrtva.
Ako smo van granica, tretiramo kao mrtvo (fiksne granice)."
  (if (life--in-bounds-p r c)
      (aref (aref grid r) c)
    0))

(defun life--set-cell (grid r c val)
  "Postavi ćeliju (R,C) na VAL (0 ili 1)."
  (when (life--in-bounds-p r c)
    (aset (aref grid r) c (if (zerop val) 0 1)))
  grid)

(defun life--count-live-neighbors (grid r c)
  "Prebroji žive susjede oko ćelije (R,C)."
  (let ((count 0))
    (cl-loop for dr from -1 to 1 do
             (cl-loop for dc from -1 to 1 do
                      (unless (and (= dr 0) (= dc 0))
                        (let ((nr (+ r dr))
                              (nc (+ c dc)))
                          (when (= 1 (life--get-cell grid nr nc))
                            (setq count (1+ count)))))))
    count))

(defun life--step-grid (grid)
  "Izračunaj sljedeću generaciju iz trenutne GRID."
  (let ((new (life--make-empty-grid)))
    (dotimes (r life-rows new)
      (dotimes (c life-cols)
        (let* ((alive (= 1 (life--get-cell grid r c)))
               (n (life--count-live-neighbors grid r c))
               (next (cond
                      ((and alive (or (= n 2) (= n 3))) 1)
                      ((and (not alive) (= n 3)) 1)
                      (t 0))))
          (life--set-cell new r c next))))))




;; ============================================================
;;  2) RENDERIRANJE u Emacs buffer
;; ============================================================

(defun life--header-lines ()
  "Koliko linija zauzima header (da znamo offset)."
  3)

(defun life--rc->point (r c)
  "Pretvori grid koordinate (R,C) u point u bufferu (grid s linijama)."
  (save-excursion
    (goto-char (point-min))
    ;; header + top border line
    (forward-line (life--header-lines))
    (forward-line 1)
    ;; svaka vrsta ima 2 linije: cell-line + border-line
    (forward-line (* r 2))
    ;; kolona: | + cell + | + cell ...
    (move-to-column (+ 1 (* c (+ life-cell-width 1))))
    (point)))

(defun life--point->rc ()
  "Pretvori trenutni point u (R . C) koordinate u mreži (grid s linijama)."
  (let* ((hdr (life--header-lines))
         (line (1- (line-number-at-pos)))
         (rel (- line hdr))          ;; 0 = top border, 1 = prvi cell-line, 2 = border, 3 = drugi cell-line...
         (col (current-column))
         r c)
    ;; red: ako smo na top border (rel=0) ili na horizontalnoj liniji, mapiramo na najbliži cell-line iznad
    (setq r
          (cond
           ((<= rel 1) 0)
           ((= (mod rel 2) 1) (/ (1- rel) 2))   ;; cell-line
           (t (/ (- rel 2) 2))))                ;; border-line -> red iznad
    ;; stupac: cell start je nakon prvog '|', pa računamo blokove širine (cell-width + 1)
    (setq c (max 0 (/ (max 0 (- col 1)) (+ life-cell-width 1))))

    (setq r (max 0 (min (1- life-rows) r)))
    (setq c (max 0 (min (1- life-cols) c)))
    (cons r c)))


(defun life--remember-cursor ()
  "Zapamti gdje je kursor u grid koordinatama."
  (let ((rc (life--point->rc)))
    (setq life--cursor-r (car rc))
    (setq life--cursor-c (cdr rc))))

(defun life--render ()
  "Nacrtaj mrežu s obojenim ćelijama i vidljivim linijama."
  (let ((inhibit-read-only t)
        (r life--cursor-r)
        (c life--cursor-c))
    (erase-buffer)

    (insert (format "Generacija: %d%s\n"
                    life--generation
                    (if life--running " (radi)" " (pauza)")))
    (insert "Kontrole: SPC start/pauza | n korak | t toggle | r random | c clear | q izlaz\n\n")

    (let ((v (propertize (char-to-string life-grid-vertical) 'face 'life-grid-face))
          (h (propertize (char-to-string life-grid-horizontal) 'face 'life-grid-face))
          (x (propertize (char-to-string life-grid-cross) 'face 'life-grid-face)))
      ;; top border
      (dotimes (_ life-cols)
        (insert x)
        (insert (propertize (make-string life-cell-width (string-to-char h)) 'face 'life-grid-face)))
      (insert x "\n")

      (dotimes (rr life-rows)
        ;; cell line
        (dotimes (cc life-cols)
          (insert v)
          (let* ((alive (= 1 (life--get-cell life--grid rr cc)))
                 (face (if alive 'life-alive-face 'life-dead-face))
                 (cell (make-string life-cell-width ?\s)))
            (insert (propertize cell 'face face))))
        (insert v "\n")

        ;; border under row
        (dotimes (_ life-cols)
          (insert x)
          (insert (propertize (make-string life-cell-width (string-to-char h)) 'face 'life-grid-face)))
        (insert x "\n")))

    (goto-char (life--rc->point r c))
    (setq buffer-read-only t)))





;; ============================================================
;;  3) TIMER (automatsko izvođenje)
;; ============================================================

(defun life--tick ()
  "Jedan 'tick' igre."
  (when life--running
    (setq life--grid (life--step-grid life--grid))
    (setq life--generation (1+ life--generation))
    (life--render)))

(defun life--start-timer ()
  "Pokreni timer ako već nije pokrenut."
  (unless (timerp life--timer)
    (setq life--timer
          (run-with-timer
           life-tick-seconds life-tick-seconds
           (lambda ()
             (when (buffer-live-p (get-buffer life-buffer-name))
               (with-current-buffer (get-buffer life-buffer-name)
                 (life--tick))))))))

(defun life--stop-timer ()
  "Zaustavi timer ako postoji."
  (when (timerp life--timer)
    (cancel-timer life--timer)
    (setq life--timer nil)))





;; ============================================================
;;  4) KOMANDE (tipke)
;; ============================================================

(defun life-toggle-run ()
  "Pokreni ili pauziraj igru."
  (interactive)
  (life--remember-cursor)
  (setq life--running (not life--running))
  (life--start-timer)
  (life--render))

(defun life-step ()
  "Jedan korak (sljedeća generacija)."
  (interactive)
  (life--remember-cursor)
  (setq life--grid (life--step-grid life--grid))
  (setq life--generation (1+ life--generation))
  (life--render))

(defun life-toggle-cell ()
  "Promijeni stanje ćelije ispod kursora (živo <-> mrtvo)."
  (interactive)
  (life--remember-cursor)
  (let* ((r life--cursor-r)
         (c life--cursor-c)
         (cur (life--get-cell life--grid r c)))
    (life--set-cell life--grid r c (if (= cur 1) 0 1)))
  (life--render))

(defun life-random ()
  "Reset na random mrežu i generaciju 0."
  (interactive)
  (life--remember-cursor)
  (setq life--grid (life--make-random-grid life-random-density))
  (setq life--generation 0)
  (life--render))

(defun life-clear ()
  "Očisti mrežu i resetiraj generaciju 0."
  (interactive)
  (life--remember-cursor)
  (setq life--grid (life--make-empty-grid))
  (setq life--generation 0)
  (life--render))

(defun life-quit ()
  "Izađi iz igre (zaustavi timer i zatvori buffer)."
  (interactive)
  (setq life--running nil)
  (life--stop-timer)
  (kill-buffer (current-buffer)))





;; ============================================================
;;  5) MAJOR MODE (poseban mod za igru)
;; ============================================================

(defvar life-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "SPC") #'life-toggle-run)
    (define-key m (kbd "n")   #'life-step)
    (define-key m (kbd "t")   #'life-toggle-cell)
    (define-key m (kbd "r")   #'life-random)
    (define-key m (kbd "c")   #'life-clear)
    (define-key m (kbd "q")   #'life-quit)
    m)
  "Keymap za life-mode.")

(defvar-local life--cursor-remap nil)

(define-derived-mode life-mode special-mode "Life"
  "Major mode za Conwayjevu Igru života."
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (setq-local cursor-type 'box)

  ;; Zapamti staru boju kursora i postavi novu (samo dok si u ovom bufferu)
  (when (display-graphic-p)
    (setq life--old-cursor-color (frame-parameter nil 'cursor-color))
    (set-cursor-color life-cursor-color))

  ;; Kad zatvoriš buffer, vrati staru boju
  (add-hook
   'kill-buffer-hook
   (lambda ()
     (when (and (display-graphic-p) life--old-cursor-color)
       (set-cursor-color life--old-cursor-color)))
   nil t))



;;;###autoload
(defun life ()
  "Pokreni Igru života u novom bufferu."
  (interactive)
  (let ((buf (get-buffer-create life-buffer-name)))
    (with-current-buffer buf
      (life-mode)
      (setq life--grid (life--make-random-grid life-random-density))
      (setq life--generation 0)
      (setq life--running nil)
      (setq life--cursor-r 0
            life--cursor-c 0)
      (life--start-timer)
      (life--render))
    (pop-to-buffer buf)))

(provide 'game_of_life)
;;; game_of_life.el ends here
