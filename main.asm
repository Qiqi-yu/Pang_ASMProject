    ; __UNICODE__ equ 1           ; uncomment to enable UNICODE build

    .686p                       ; create 32 bit code
    .mmx                        ; enable MMX instructions
    .xmm                        ; enable SSE instructions
    .model flat, stdcall        ; 32 bit memory model
    option casemap :none        ; case sensitive

    bColor   equ  <00999999h>   ; client area brush colour
    include game.inc      ; local includes for this file

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
		; �������̧���¼�

	.ELSEIF uMsg == WM_KEYDOWN
		; ������̰����¼�

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
	invoke LoadBitmap, hInstance, 500
	mov h_gamepage, eax
	ret
loadGameImages endp

; һ���̺߳��������ݳ�����״̬����ѭ������Ϸ״̬ʱ�򣬲��Ͻ�����ײ�жϵȵ�
logicThread proc p:DWORD
	LOCAL area:RECT
	
	.WHILE 1
		invoke Sleep, 30
	.ENDW
	ret
logicThread endp

; ���Ͻ��л�������
paintThread proc p:DWORD
	.WHILE 1
		invoke Sleep, 10
		invoke InvalidateRect, hWnd, NULL, FALSE
	.ENDW
	ret
paintThread endp

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
	;.IF game_status == 0
		invoke SelectObject, member_hdc2,  h_gamepage
		invoke BitBlt, member_hdc1, 0, 0, my_window_width, my_window_height, member_hdc2, 0, 0, SRCCOPY
	;.ENDIF
	ret
paintBackground endp

end start