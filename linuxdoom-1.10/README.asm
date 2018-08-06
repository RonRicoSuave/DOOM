
Note: 
The below is a quick conversion to Intel syntax which clang should build without complaining, but I'm not testing this.  
Unecessary instruction postfixes have been removed and provided as operand size directives where they cannot be 
inferred by the compiler.  Some branch constructs were changed slightly for modern hardware with branch prediction.  Otherwise, things have been left as-is.  

README - DOOM assembly code

Okay, I add the DOS assembly module for the historically
inclined here (may rec.games.programmer suffer). If anyone
feels the urge to port these to GNU GCC; either inline or
as separate modules including Makefile support, be my guest.

Module tmap.S includes the inner loops for texture mapping,
the interesting one being the floor/ceiling span rendering.

There was another module in the source dump, fpfunc.S, that
had both texture mapping and fixed point functions. It
contained implementations both for i386 and M68k. For
brevity, I include only the i386 fixed point stuff below.

;====================================================
; tmap.S  as of January 10th, 1997
; updated syntax, untested 2018

;================
;
; R_DrawColumn
;
;================

	.data
loopcount	dd	0
pixelcount	dd	0

	.text

	.align 16
.globl _R_DrawColumn
_R_DrawColumn:

	pushad

	mov		ebp, [_dc_yl]
	mov		ebx, ebp
	mov     edi, [_ylookup + ebx*4]
	mov		ebx, [_dc_x]
	add     edi, [_columnofs + ebx*4]

	mov		eax,[_dc_yh]
	inc		eax
	sub     eax,ebp                   	; pixel count
	mov		[pixelcount], eax			; save for final pixel
	js		done						; nothing to scale
	shr		eax, 1						; double pixel count (this halves it. bug or bad comment?)
	mov		[loopcount], eax
	
	mov     ecx, [_dc_iscale]

	mov		eax, [_centery]
	sub		eax, ebp
	imul	ecx
	mov		ebp, [_dc_texturemid]
	sub		ebp, eax
	shl		ebp, 9						; 7 significant bits, 25 frac

	mov     esi, [_dc_source]
	

	mov		ebx, [_dc_iscale]
	shl		ebx, 9
	mov		eax, OFFSET patch1+2		; convice tasm to modify code...
	mov		[eax], ebx
	mov		eax, OFFSET patch2+2		; convice tasm to modify code...
	mov		[eax], ebx
	
; eax		aligned colormap
; ebx		aligned colormap
; ecx,edx	scratch
; esi		virtual source
; edi		moving destination pointer
; ebp		frac
	
	mov	ecx, ebp					; begin calculating first pixel
	add	ebp, ebx					; advance frac pointer
	shr ecx, 25					; finish calculation for first pixel
	mov	edx, ebp					; begin calculating second pixel
	add	ebp, ebx					; advance frac pointer
	shr edx, 25					; finish calculation for second pixel
	mov eax, [_dc_colormap]
	mov ebx, eax
	mov	al, [esi+ecx]			; get first pixel
	mov	bl, [esi+edx]			; get second pixel
	mov	al, [eax]				; color translate first pixel
	mov	bl, [ebx]				; color translate second pixel
	
	mov ecx, [pixelcount]
	test ecx, 0fffffffeh		; changed to two instructions to avoid mem/imm test
	jz checklast 
	; this was a jnz / jmp pair.  switched to jz / fallthrough 
	; because this branch will be predicted not taken on the first
	; run so we might as well limit the mispredict to the last run	
	
	.align	16
doubleloop:
	mov	ecx, ebp				; begin calculating third pixel
patch1:
	add	ebp, 12345678h			; advance frac pointer
	mov	[edi], al				; write first pixel
	shr ecx, 25					; finish calculation for third pixel
	mov	edx, ebp				; begin calculating fourth pixel
patch2:
	add	ebp, 12345678h			; advance frac pointer
	mov	[edi+SCREENWIDTH], bl	; write second pixel
	shr edx, 25					; finish calculation for fourth pixel
	mov	al, [esi+ecx]			; get third pixel
	add	edi, SCREENWIDTH*2		; advance to third pixel destination
	mov	bl, [esi+edx]			; get fourth pixel
	dec	DWORD PTR [loopcount]	; done with loop?
	mov	al, [eax]				; color translate third pixel
	mov	bl, [ebx]				; color translate fourth pixel
	jnz	doubleloop
	
; check for final pixel
checklast:
	test DWORD PTR [pixelcount], 1
	jz	done
	mov	[edi], al				; write final pixel
	
done:
	popa
	ret
	


;================
;
; R_DrawSpan
;
; Horizontal texture mapping
;
;================


	.align	16
.globl _R_DrawSpan
_R_DrawSpan:
	pushad

;
; find loop count
;	
	mov		eax, [_ds_x2]
	inc		eax
	sub     eax, [_ds_x1]              	; pixel count
	mov		[pixelcount], eax			; save for final pixel
	js		hdone						; nothing to scale
	shr		eax, 1						; double pixel count (this halves it... bug or bad comment?)
	mov		[loopcount], eax

; build composite position
	mov	ebp, [_ds_xfrac]
	shl	ebp, 10
	and	ebp, 0ffff0000h
	mov	eax, [_ds_yfrac]
	shr	eax, 6
	and	eax, 0ffffh
	or	ebp, eax

	mov	esi, [_ds_source]

; calculate screen dest
	mov	edi, [_ds_y]
	mov	edi, [_ylookup + edi*4]
	mov	eax, [_ds_x1]
	add edi, [_columnofs + eax*4]

;
; build composite step
;
	mov	ebx, [_ds_xstep]
	shl	ebx, 10
	and	ebx, 0ffff0000h
	mov	eax, [_ds_ystep]
	shr	eax, 6
	and	eax, 0ffffh
	or	ebx, eax

	movl		eax, OFFSET hpatch1+2		; self-modifying code loc 1
	movl		[eax], ebx
	movl		eax, OFFSET hpatch2+2		; self-modifying code loc 2
	movl		[eax], ebx
	
; eax		aligned colormap
; ebx		aligned colormap
; ecx,edx	scratch
; esi		virtual source
; edi		moving destination pointer
; ebp		frac
	
	shld ecx, ebp, 22			; begin calculating third pixel (y units)
	shld ecx, ebp, 6			; begin calculating third pixel (x units)
	add	ebp, ebx				; advance frac pointer
	and ecx, 4095				; finish calculation for third pixel
	shld edx, ebp, 22			; begin calculating fourth pixel (y units)
	shld edx, ebp, 6			; begin calculating fourth pixel (x units)
	add	ebp, ebx		 		; advance frac pointer
	and edx, 4095				; finish calculation for fourth pixel
	mov eax, [_ds_colormap]
	mov ebx, eax
	mov	al, [esi+ecx]			; get first pixel
	mov	bl, [esi+edx]			; get second pixel
	mov	al, [eax]				; color translate first pixel
	mov	bl, [ebx]				; color translate second pixel
	
	test DWORD PTR [pixelcount], 0fffffffeh
	jz	hchecklast				; at least two pixels to map
	
	; this was a jnz / jmp pair.  switched to jz / fallthrough 
	; because this branch will be predicted not taken.  the jmp to 
	; hchecklast would cause a speculative pre-fetch of that on 
	; current hardware. 
	
	.align	16
hdoubleloop:
	shld ecx, ebp, 22			; begin calculating third pixel (y units)
	shld ecx, ebp, 6			; begin calculating third pixel (x units)
hpatch1:
	add	ebp, 12345678h			; advance frac pointer
	mov	[edi], al				; write first pixel
	and ecx, 4095				; finish calculation for third pixel
	shld edx, ebp, 22			; begin calculating fourth pixel (y units)
	shld edx, ebp, 6			; begin calculating fourth pixel (x units)
hpatch2:
	add	ebp, 12345678h			; advance frac pointer
	mov	[edi+1], bl				; write second pixel
	and edx, 4095				; finish calculation for fourth pixel
	mov	al, [esi+ecx]			; get third pixel
	add	edi, 2					; advance to third pixel destination
	mov	bl, [esi+edx]			; get fourth pixel
	dec	DWORD PTR [loopcount]	; done with loop?
	mov	al, [eax]				; color translate third pixel
	mov	bl, [ebx]				; color translate fourth pixel
	jnz	hdoubleloop

; check for final pixel
hchecklast:
	test DWORD PTR [pixelcount], 1
	jz hdone
	movb [edi], al				; write final pixel
	
hdone:
	popa
	ret




;====================================================
; fpfunc.S  as of January 10th, 1997 (parts)

#ifdef i386

.text
	.align 4
.globl _FixedMul
_FixedMul:	
	push ebp
	mov ebp, esp
	mov eax, [ebp+8]
	imul [ebp+12]
	shrd eax, edx, 16
	pop ebp
	ret

	.align 4
.globl _FixedDiv2
_FixedDiv2:
	push ebp
	mov ebp, esp
	mov eax, [ebp+8]
	cdq
	shld edx, eax, 16
	sal eax, 16
	idiv [ebp + 12]
	pop ebp
	ret

#endif

