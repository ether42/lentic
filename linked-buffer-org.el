;;; linked-buffer-org.el --- org support for linked-buffer -*- lexical-binding: t -*-

;;; Header:

;; This file is not part of Emacs

;; Author: Phillip Lord <phillip.lord@newcastle.ac.uk>
;; Maintainer: Phillip Lord <phillip.lord@newcastle.ac.uk>

;; The contents of this file are subject to the LGPL License, Version 3.0.

;; Copyright (C) 2014, Phillip Lord, Newcastle University

;; This program is free software: you can redistribute it and/or modify it
;; under the terms of the GNU Lesser General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.

;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
;; for more details.

;; You should have received a copy of the GNU Lesser General Public License
;; along with this program. If not, see http://www.gnu.org/licenses/.

;;; Commentary:

;; This file provides linked-buffer for org and emacs-lisp files. This enables a
;; literate form of programming with Elisp, using org mode to provide
;; documentation mark up.

;; It provides too main ways of integrating between org and emacs-lisp. The
;; first which we call org-el (or el-org) is a relatively simple translation
;; between the two modes.


;; #+BEGIN_SRC emacs-lisp
(require 'linked-buffer-block)
;; #+END_SRC

;;; Code:

;; ** Simple org->el

;; The simple transformation between org and elisp is to just comment out
;; everything that is not inside a BEGIN_SRC/END_SRC block. This provides only
;; minimal advantages over the embedded org mode environment. Org, for instance,
;; allows native fontification of the embedded code (i.e. elisp will be coloured
;; like elisp!), which is something that org-el translation also gives for free;
;; in this case of org-el, however, when the code is high-lighted, the org mode
;; text is visually reduced to `comment-face'. The other key advantage is
;; familiarity; it is possible to switch to the `emacs-lisp-mode' buffer and
;; eval-buffer, region or expression using all the standard keypresses.

;; One problem with this mode is that elisp has a first line semantics for
;; file-local variables. This is a particular issue if setting `lexical-binding'.
;; In a literate org file, this might appear on the first line of the
;; embedded lisp, but it will *not* appear in first line of an emacs-lisp
;; linked-buffer, so the file will be interpreted with dynamic binding.

;;; Implementation:

;; The implementation is a straight-forward use of `linked-buffer-block' with
;; regexps for org source blocks. It currently takes no account of
;; org-mode :tangle directives -- so all lisp in the buffer will be present in
;; the emacs-lisp mode linked-buffer.

;; #+BEGIN_SRC emacs-lisp
(defun linked-buffer-org-to-el-new ()
  (linked-buffer-uncommented-block-configuration
   "lb-org-to-el"
   :this-buffer (current-buffer)
   :linked-file
   (concat
    (file-name-sans-extension
     (buffer-file-name))
    ".el")
   :comment ";; "
   :comment-stop "#\\\+BEGIN_SRC emacs-lisp"
   :comment-start "#\\\+END_SRC"))

(defun linked-buffer-org-el-init ()
  (setq linked-buffer-config
        (linked-buffer-org-to-el-new)))

(add-to-list 'linked-buffer-init-functions
             'linked-buffer-org-el-init)

(defun linked-buffer-el-to-org-new ()
  (linked-buffer-commented-block-configuration
   "lb-el-to-org"
   :this-buffer (current-buffer)
   :linked-file
   (concat
    (file-name-sans-extension
     (buffer-file-name))
    ".org")
   :comment ";; "
   :comment-stop "#\\\+BEGIN_SRC emacs-lisp"
   :comment-start "#\\\+END_SRC"))

(defun linked-buffer-el-org-init ()
  (setq linked-buffer-config
        (linked-buffer-el-to-org-new)))

(add-to-list 'linked-buffer-init-functions
             'linked-buffer-el-org-init)
;; #+END_SRC


;; ** orgel->org

;; In this section, we define a different transformation from what we call an
;; orgel file. This is a completely valid emacs-lisp file which transforms
;; cleanly into a valid org file. This requires constraits on both the emacs-lisp
;; and org representation. However, most of the features of both modes are
;; available.

;; The advantages of orgel files over a tangle-able literate org file are
;; several. The main one, however, is that the =.el= file remains a source
;; format. It can be loaded directly by Emacs with `load-library' or `require'.
;; Developers downloading from a VCS will find the =.el= file rather than looking
;; for an =.org= file. Developers wishing to offer patches can do so to the =.el=
;; file. Finally, tools which work over =.el= such as checkdoc will still work.
;; Finally, there is no disjoint between the org file and the emacs-lisp
;; comments. The commentary section, for example, can be edited using `org-mode'
;; rather than as comments in an elisp code block.

;; The disadvantages are that the structure of the org file is not arbitrary; it
;; most follow a specific structure. Without an untangling process, things like
;; noweb references will not work.

;; The transformation (orgel -> org) works as follows:
;;  - the first line summary is transformed into a comment in org
;;  - all single word ";;;" headers are transformed into level 1 org headings.
;;  - ";;" comments are removed except inside emacs-lisp source blocks.

;; *** Converting an Existing file

;; It is relatively simple to convert an existing emacs-lisp file, so that it
;; will work with the orgel transformation.



;; *** Limitations

;; Currently, the implementation still requires some extra effort from the elisp
;; side, in that lisp must be marked up as a source code block. The short term
;; fix would be to add some functionality like `org-babel-demarcate-block' to
;; emacs-lisp-mode. Even better would to automatically add source markup when "("
;; was pressed at top level (if paredit were active, then it would also be
;; obvious where to put the close). Finally, have both `linked-buffer-org' and
;; `org-mode' just recognise emacs-lisp as a source entity *without* any further
;; markup.

;; Finally, I don't like the treatment of the summary line -- ideally this should
;; appear somewhere in the org file not as a comment. I am constrained by the
;; start of file semantics of both =.org= and =.el= so this will probably remain.
;; The content can always be duplicated which is painful, but the summary line is
;; unlikely to get updated regularly.

;; *** Implementation

;; The main transformation issue is the first line. An =.el= file has a summary
;; at the top. This is checked by checkdoc, used by the various lisp management
;; tools, which in turn impacts on the packaging tools. Additionally, lexical
;; binding really must be set here.

;; We solve this problem by transforming the first line ";;;" into "# #". Having
;; three characters means that the width is maintained. It also means I can
;; distinguish between this kind of comment and an "ordinary" `org-mode' comment;
;; in practice, this doesn't matter, because I only check on the first line. The
;; space is necessary because `org-mode' doesn't recognised "###" as a comment.

;; Another possibility would be to transform the summary line into a header. I
;; choose against this because first it's not really a header being too long and
;; second `org-mode' uses the space before the first header to specify, for
;; example, properties relevant to the entire tree. This is prevented if I make
;; the first line a header 1.

;; **** org to orgel

;; Here we define a new class or org-to-orgel, as well as clone function which
;; adds the ";;;" header transformation in addition to the normal block semantics
;; from the superclass. Currently only single word headers are allowed which
;; seems consistent with emacs-lisp usage.

;; #+BEGIN_SRC emacs-lisp
(defclass linked-buffer-org-to-orgel-configuration
  (linked-buffer-uncommented-block-configuration)
  ())

(defmethod linked-buffer-clone
  ((conf linked-buffer-org-to-orgel-configuration))
  ;; do everything else to the buffer
  (call-next-method conf)
  (m-buffer-replace-match
   (m-buffer-match
    (linked-buffer-that conf)
    ";; # # "
    :end
    (cadr
     (car
      (m-buffer-match-line
       (linked-buffer-that conf)))))
   ";;; ")
  ;; replace big headers
  (m-buffer-replace-match
   (m-buffer-match (linked-buffer-that conf)
                   "^;; [*] \\(\\\w*\\)")
   ";;; \\1:"))

(defmethod linked-buffer-invert
  ((conf linked-buffer-org-to-orgel-configuration))
  (let ((rtn
         (linked-buffer-orgel-to-org-new)))
    (oset rtn :that-buffer
          (linked-buffer-this conf))
    rtn))

(defun linked-buffer-org-to-orgel-new ()
  (linked-buffer-org-to-orgel-configuration
   "lb-orgel-to-el"
   :this-buffer (current-buffer)
   :linked-file
   (concat
    (file-name-sans-extension
     (buffer-file-name))
    ".el")
   :comment ";; "
   :comment-stop "#\\\+BEGIN_SRC emacs-lisp"
   :comment-start "#\\\+END_SRC"))

(defun linked-buffer-org-orgel-init ()
  (setq linked-buffer-config
        (linked-buffer-org-to-orgel-new)))

(add-to-list 'linked-buffer-init-functions
             'linked-buffer-org-orgel-init)
;; #+END_SRC

;; **** orgel->org

;; And the orgel->org implementation. Currently, this means that I have all the
;; various regexps in two places which is a bit ugly. I am not sure how to stop
;; this.

;; #+BEGIN_SRC emacs-lisp

(defclass linked-buffer-orgel-to-org-configuration
  (linked-buffer-commented-block-configuration)
  ())

(defmethod linked-buffer-clone
  ((conf linked-buffer-orgel-to-org-configuration))
  ;; do everything else to the buffer
  (call-next-method conf)
  (m-buffer-replace-match
   (m-buffer-match
    (linked-buffer-that conf)
    ";;; "
    :end
    (cadr
     (car
      (m-buffer-match-line
       (linked-buffer-that conf)))))
   "# # ")
  (m-buffer-replace-match
   (m-buffer-match (linked-buffer-that conf)
                   "^;;; \\(\\\w*\\):")
   "* \\1"))

(defmethod linked-buffer-invert
  ((conf linked-buffer-orgel-to-org-configuration))
  (let ((rtn
         (linked-buffer-org-to-orgel-new)))
    (oset rtn :that-buffer (linked-buffer-this conf))
    rtn))

(defun linked-buffer-orgel-to-org-new ()
  (linked-buffer-orgel-to-org-configuration
   "lb-orgel-to-org"
   :this-buffer (current-buffer)
   ;; we don't really need a file and could cope without, but org mode assumes
   ;; that the buffer is file name bound when it exports. As it happens, this
   ;; also means that file saving is possible which in turn saves the el file
   :linked-file
   (concat
    (file-name-sans-extension
     (buffer-file-name))
    ".org")
   :comment ";; "
   :comment-stop "#\\\+BEGIN_SRC emacs-lisp"
   :comment-start "#\\\+END_SRC"))

(defun linked-buffer-orgel-org-init ()
  (setq linked-buffer-config
        (linked-buffer-orgel-to-org-new)))

(add-to-list 'linked-buffer-init-functions
             'linked-buffer-orgel-org-init)

;; #+END_SRC



;; ** org->clojure

;; #+BEGIN_SRC emacs-lisp
(defun linked-buffer-org-to-clojure-new ()
  (linked-buffer-uncommented-block-configuration
   "lb-org-to-clojure"
   :this-buffer (current-buffer)
   :linked-file
   (concat
    (file-name-sans-extension
     (buffer-file-name))
    ".clj")
   :comment ";; "
   :comment-stop "#\\\+BEGIN_SRC clojure"
   :comment-start "#\\\+END_SRC"
   ;; don't ignore case -- so using lower case begin_src
   ;; will be ignored. Probably we should count instead!
   :case-fold-search nil))

(defun linked-buffer-org-clojure-init ()
  (setq linked-buffer-config
        (linked-buffer-org-to-clojure-new)))

(add-to-list 'linked-buffer-init-functions
             'linked-buffer-org-clojure-init)

(defun linked-buffer-clojure-to-org-new ()
  (linked-buffer-commented-block-configuration
   "lb-clojure-to-org"
   :this-buffer (current-buffer)
   :linked-file
   (concat
    (file-name-sans-extension
     (buffer-file-name))
    ".org")
   :comment ";; "
   :comment-stop "#\\\+BEGIN_SRC clojure"
   :comment-start "#\\\+END_SRC"))

(defun linked-buffer-clojure-org-init ()
  (setq linked-buffer-config
        (linked-buffer-clojure-to-org-new)))

(add-to-list 'linked-buffer-init-functions
             'linked-buffer-clojure-org-init)
;; #+END_SRC


;;; Footer:

;; Declare the end of the file, and add file-local support for orgel->org
;; transformation. Do not use linked-buffers on this file while changing the
;; lisp in the file without backing up first!

;; #+BEGIN_SRC emacs-lisp
(provide 'linked-buffer-org)
;;; linked-buffer-org.el ends here
;; #+END_SRC


;; # Local Variables:
;; # linked-buffer-init: linked-buffer-orgel-org-init
;; # End:
