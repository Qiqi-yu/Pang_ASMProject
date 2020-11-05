    ; __UNICODE__ equ 1           ; uncomment to enable UNICODE build

    .686p                       ; create 32 bit code
    .mmx                        ; enable MMX instructions
    .xmm                        ; enable SSE instructions
    .model flat, stdcall        ; 32 bit memory model
    option casemap :none        ; case sensitive

    bColor   equ  <00999999h>   ; client area brush colour
    include	game.inc      ; local includes for this file
	;include Irvine32.inc
	

.code
start:  ;������ڵ�
    ; ���ģ����
	invoke GetModuleHandle, NULL
	mov hInstance, eax

	; ���ܲ���Ҫ�����в���
	invoke GetCommandLine
	mov  CommandLine, eax
	; �õ�ͼ��͹��
    mov hIcon,       rv(LoadIcon,hInstance,103)
    mov hCursor,     rv(LoadCursor,NULL,IDC_ARROW)
	; �õ�������Ļ�ĳߴ�
    mov sWid,        rv(GetSystemMetrics,SM_CXSCREEN)
    mov sHgt,        rv(GetSystemMetrics,SM_CYSCREEN)
	; ����������
    call Main
    invoke ExitProcess, eax

Main proc
    LOCAL Wwd:DWORD,Wht:DWORD,Wtx:DWORD,Wty:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL icce:INITCOMMONCONTROLSEX

  ; --------------------------------------
  ; comment out the styles you don't need.
  ; --------------------------------------
    mov icce.dwSize, SIZEOF INITCOMMONCONTROLSEX            ; set the structure size
    xor eax, eax                                            ; set EAX to zero
    or eax, ICC_WIN95_CLASSES
    or eax, ICC_BAR_CLASSES                                 ; comment out the rest
    mov icce.dwICC, eax
    invoke InitCommonControlsEx,ADDR icce                   ; initialise the common control library
  ; --------------------------------------

    STRING szClassName,   "GameClass"
    STRING szDisplayName, "Happy Game"

  ; ---------------------------------------------------
  ; set window class attributes in WNDCLASSEX structure
  ; ---------------------------------------------------
    mov wc.cbSize,         sizeof WNDCLASSEX
    mov wc.style,          CS_BYTEALIGNCLIENT or CS_BYTEALIGNWINDOW
    m2m wc.lpfnWndProc,    OFFSET WndProc
    mov wc.cbClsExtra,     NULL
    mov wc.cbWndExtra,     NULL
    m2m wc.hInstance,      hInstance
    m2m wc.hbrBackground,  NULL                 ;COLOR_BTNFACE+1 ����Ҫbackground
    mov wc.lpszMenuName,   NULL
    mov wc.lpszClassName,  OFFSET szClassName  ;;
    m2m wc.hIcon,          hIcon
    m2m wc.hCursor,        hCursor
    m2m wc.hIconSm,        hIcon

  ; ------------------------------------
  ; register class with these attributes
  ; ------------------------------------
    invoke RegisterClassEx, ADDR wc

  ; ---------------------------------------------
  ; set width and height abosulte length
  ; ---------------------------------------------
    mov Wwd, my_window_width
    mov Wht, my_window_height

  ; ------------------------------------------------
  ; Top X and Y co-ordinates for the centered window
  ; ------------------------------------------------
    mov eax, sWid
    sub eax, Wwd                ; sub window width from screen width
    shr eax, 1                  ; divide it by 2
    mov Wtx, eax                ; copy it to variable

    mov eax, sHgt
    sub eax, Wht                ; sub window height from screen height
    shr eax, 1                  ; divide it by 2
    mov Wty, eax                ; copy it to variable

  ; -----------------------------------------------------------------
  ; create the main window with the size and attributes defined above
  ; -----------------------------------------------------------------
    invoke CreateWindowEx,WS_EX_LEFT or WS_EX_ACCEPTFILES,
                          ADDR szClassName,
                          ADDR szDisplayName,
                          WS_OVERLAPPED or WS_SYSMENU,
                          Wtx,Wty,Wwd,Wht,
                          NULL,NULL,
                          hInstance,NULL
    mov hWnd,eax
    invoke ShowWindow,hWnd, SW_SHOWNORMAL
    invoke UpdateWindow,hWnd

	; ��Ϣѭ��
    call MsgLoop
    ret
Main endp

; ��Ϣѭ��
MsgLoop proc
    LOCAL msg:MSG
    push ebx
    lea ebx, msg
    jmp getmsg
  msgloop:
    invoke TranslateMessage, ebx
    invoke DispatchMessage,  ebx
  getmsg:
    invoke GetMessage,ebx,0,0,0
    test eax, eax
    jnz msgloop
    pop ebx
    ret
MsgLoop endp

WndProc proc hWin:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
	; �����ڴ������һЩ����
	.IF uMsg == WM_CREATE
		; ����λͼ��Դ
		invoke loadGameImages
		; �����߼��߳�
		mov eax, OFFSET logicThread
		invoke CreateThread, NULL, NULL, eax, 0, 0, addr thread1
		invoke CloseHandle, eax
		; ��������߳�
		mov eax, OFFSET paintThread
		invoke CreateThread, NULL, NULL, eax, 0, 0, addr thread2
		invoke CloseHandle, eax

	.ELSEIF uMsg == WM_DESTROY
		; �˳��߳�
		invoke PostQuitMessage, NULL

	.ELSEIF uMsg == WM_PAINT
		; ���ø��³���������WM_PAINT��paintThread��InvalidateRect����
		invoke updateScene

	.ELSEIF uMsg == WM_CHAR
		; ����enter�������¼�

	.ELSEIF uMsg == WM_KEYUP
		invoke processKeyUp, wParam
		; �������̧���¼�

	.ELSEIF uMsg == WM_KEYDOWN
		; ������̰����¼�
		invoke processKeyDown, wParam
	.ELSE 
		; Ĭ����Ϣ������
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.ENDIF
	xor eax, eax
	ret
WndProc endp

loadGameImages proc
	; ���ؿ�ʼ�����λͼ

    ; ������Ϸ�����λͼ
	invoke LoadBitmap, hInstance, 501
	mov h_gamepage, eax

	; �������1��λͼ
	invoke LoadBitmap, hInstance, 502
	mov player1_bitmap, eax

	; ����ש���λͼ
	invoke LoadBitmap, hInstance, 503
	mov brick_bitmap, eax

	ret
loadGameImages endp

; һ���̺߳��������ݳ�����״̬����ѭ������Ϸ״̬ʱ�򣬲��Ͻ�����ײ�жϵȵ�
logicThread proc p:DWORD
	;LOCAL area:RECT
	; ��ʼ���棬�����û��ֶ�����ָ�Ͻ��棬���ߵ�ʱ���Զ�����
	.WHILE game_status == 0
		;invoke Sleep, 1000
		mov game_status, 2
		invoke initialBricks
	.ENDW

	game:

	; ָ�Ͻ���
	.WHILE game_status == 1
		invoke Sleep, 30
	.ENDW

	; ��Ϸ����
	.WHILE game_status == 2
		invoke Sleep, 30 
		inc game_counter
		.IF game_counter >= 80
			invoke changeBricks
			mov game_counter, 0
		.ENDIF
	 
		invoke movePlayer, addr player1
	 

	.ENDW

	; ʤ������
	;.WHILE game_status == 3 || game_status == 4
	;	invoke Sleep, 30
	;.ENDW

	jmp game
	
	ret
logicThread endp

; ש����º���
changeBricks proc
	
	ret
changeBricks endp

movePlayer proc uses eax ebx, addrPlayer1:DWORD
	assume eax: PTR player
	mov eax,addrPlayer1

	.IF [eax].is_y_collide == 0
	mov [eax].speed.y,6
	.ELSE
    mov [eax].speed.y,0
	.ENDIF

	mov ebx,[eax].speed.y
	add [eax].pos.y,ebx
	mov ebx,[eax].speed.x
	add [eax].pos.x,ebx

	ret

movePlayer endp

processKeyDown proc wParam:WPARAM
	.IF game_status == 2
		.IF wParam == VK_LEFT
			mov player1.speed.x,-6
		.ELSEIF wParam == VK_RIGHT
			mov player1.speed.x,6
		.ENDIF
	.ENDIF
	ret
processKeyDown endp

processKeyUp proc wParam:WPARAM
	.IF game_status == 2
		.IF wParam == VK_LEFT
			mov player1.speed.x,0
		.ELSEIF wParam == VK_RIGHT
			mov player1.speed.x,0
		.ENDIF
	.ENDIF
	ret
processKeyUp endp

; ���Ͻ��л�������
paintThread proc p:DWORD
	.WHILE 1
		invoke Sleep, 10
		invoke InvalidateRect, hWnd, NULL, FALSE
	.ENDW
	ret
paintThread endp

initialBricks proc uses esi edx ecx eax ebx
	;invoke    randomize
	mov	   ecx, lengthof bricks
	mov	   esi, offset bricks
L1:
	    ;pushad
		mov		eax, 0
		;invoke  randomrange
		;popad
		; ����ط�û�����qwq
		push	ecx
		mov		dx, 0
		mov		cx, 7
		div		cx
		mov		[esi], dx
		add		esi, TYPE bricks
		pop		ecx
		loop	L1
	ret
initialBricks endp

; �������º���
updateScene proc uses eax
	LOCAL member_hdc:HDC
	LOCAL member_hdc2:HDC
	LOCAL h_bitmap:HDC
	LOCAL hdc: HDC

	invoke BeginPaint, hWnd, ADDR paintstruct
	mov hdc, eax
	invoke CreateCompatibleDC, hdc
	mov member_hdc, eax
	invoke CreateCompatibleDC, hdc
	mov member_hdc2, eax
	invoke CreateCompatibleBitmap, hdc, my_window_width, my_window_height
	mov h_bitmap, eax

	;��λͼѡ�񵽼���DC��
	invoke SelectObject, member_hdc, h_bitmap

	;���Ʊ���
	invoke paintBackground, member_hdc, member_hdc2

    ;����ש��
	invoke paintBricks, member_hdc, member_hdc2

    ;��������
	invoke paintPlayers, member_hdc, member_hdc2

    ;���Ʒ���

	; BitBlt��hDestDC, x, y, nWidth, nheight, hSrcDC, xSrc, ySrc, dwRop��
	; ��Դ��������ֱ�ӿ�����Ŀ������SRCCOPY
	invoke BitBlt, hdc, 0, 0, my_window_width, my_window_height, member_hdc, 0, 0, SRCCOPY
	
	invoke DeleteDC, member_hdc
	invoke DeleteDC, member_hdc2
	invoke DeleteObject, h_bitmap
	invoke EndPaint, hWnd, ADDR paintstruct
	ret
updateScene endp

; ����ͼƬ���ƺ���
paintBackground proc  member_hdc1:HDC, member_hdc2:HDC
	.IF game_status == 2
		invoke SelectObject, member_hdc2,  h_gamepage
		invoke BitBlt, member_hdc1, 0, 0, my_window_width, my_window_height, member_hdc2, 0, 0, SRCCOPY
	.ENDIF

	ret
paintBackground endp

; ��Ϸ���ǻ��ƺ���
paintPlayers proc member_hdc1: HDC, member_hdc2:HDC
	invoke SelectObject, member_hdc2, player1_bitmap

	invoke TransparentBlt, member_hdc1,player1.pos.x,player1.pos.y,\
			player1.psize.x, player1.psize.y, member_hdc2, 0, 0, 40, 40, 16777215
	
	ret
paintPlayers endp




; ש����ƺ���
paintBricks proc uses esi edi ebx edx eax, member_hdc1:HDC, member_hdc2:HDC 
	LOCAL  brick_x :DWORD
	LOCAL  brick_y :DWORD

	mov	   ecx, lengthof bricks
	mov    edi, offset bricks
	mov	   esi, 50
	sub    esi, game_counter
L2:
		mov ebx, [edi]  ; ���� ש�������
		mov eax, brick_gap  ; ������  75
		mul ebx
		mov	brick_x, eax
		mov brick_y, esi
		pushad
		invoke SelectObject, member_hdc2, brick_bitmap
		invoke TransparentBlt, member_hdc1, brick_x, brick_y,\
			brick_width, brick_height, member_hdc2, 0, 0, 150, 30, 16777215
		popad
		add esi, 80
		add edi, TYPE bricks
		loop L2
	ret
paintBricks endp

end start