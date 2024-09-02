.intel_syntax noprefix

.text
  .global _start

  .code16

  _start:

  mov ds:_disk_id, dl

  # 清除寄存器
  # 不清除會導致在各個仿真器/虛擬機上行爲不同
  mov ax, 0x0000
  mov cx, ax
  mov dx, ax
  mov bx, ax
  mov ds, ax
  mov es, ax
  mov fs, ax
  mov gs, ax

  # 重置顯示器
  call _func_reset_screen

  # 加載程序主體部分
  call _func_load_bootim

  # 加載全局描述符表
  call _func_load_gdt
    cmp ax, 0
    jnz _flag_panic

  call _func_print_newline
  lea ax, _msg_booting
  call _func_print

  # 進入保護模式
  xor eax, eax
  cli               # 關閉中斷
  in al, 0x92       # 使用快速 A20 門
  or al, 2          # 啓用 A20 綫
  out 0x92, al
  mov eax, cr0
  or al, 1          # 啓用保護位
  mov cr0, eax

  # 原神，啓動！
  xchg bx, bx

  # 加載內核入口偏移
  ljmp [0x8000]
  hlt

  # 打印字串
  #   ax = 字串指針
  _func_print:
    mov si, ax      # 參數 字串所在指針
    
    _flag_print_continue:
      lodsb           # 加載指針
      cmp al, 0x00    # 是否加載成功
      jz _flag_print_break
      
      mov ah, 0x0e    # 中斷函數
      int 0x10
      jmp _flag_print_continue

    _flag_print_break:
  ret

  _func_print_newline:
    lea ax, _msg_newline
    jmp _func_print

  # 重置默認顯示器
  _func_reset_screen:
    mov ax, 0x0003  # 設置顯示器 (80x25 16色文本)
    int 0x10
  ret

  # 解析 bootim 並加載
  # 返回 ax 爲 main 指針
  _func_load_bootim:

    # 先讀取 bootim 所在的扇區，並解析
    xor ax, ax
    mov es, ax
    mov bx, 0x7e00 # 0x0000(es):0x7e00(bx) = 0x7e00
    mov cl, 0x02   # bootim 在第 2 扇區
    mov ch, 0x01   # 讀取 1 個扇區到內存
    mov al, ds:_disk_id  # 啓動的磁盤號, BIOS設置
    call _func_read_drive

    # 判斷幻數 ELKERNEL
    mov ax, es:0x7e00
    mov bx, es:0x7e02
    mov cx, es:0x7e04
    mov dx, es:0x7e06
      cmp ax, 0x4c45 # EL
        jnz _flag_no_bootim
      cmp bx, 0x454b # KE
        jnz _flag_no_bootim
      cmp cx, 0x4e52 # RN
        jnz _flag_no_bootim
      cmp dx, ax # EL
        jnz _flag_no_bootim

    # 打印版本字符串
    mov ax, 0x7e20
    call _func_print
    call _func_print_newline

    # 0x7e10 爲 bootim 中定義內核的頁數
    mov ax, [es:0x7e10]
    mov ds:_bootim_pages, ax
    # xchg bx, bx

    # 好的 那把內核全部請進來吧 (?
    lea si, ds:_disk_lba_desc

    # 裝填結構體 (爲了節省空間 註釋了沒用的代碼)
    movb [si], 0x10          # 大小
    # movb [bx + 1], 0x00    # 保留
    # movw [si + 2], 127     # 要讀取的扇區數
    # movw [bx + 4], 0x0000  # 偏移
    movw [si + 6], 0x0800    # 段
    movw [si + 8], 2         # LBA48 低32位 (內核在第3扇區)
    # movw [bx + 10], 0      # LBA48 低32位
    # movw [bx + 12], 0      # LBA48 高16位

    # 因爲僅靠 LBA48 的低16位
    # 我們就能尋址至多 512B * 0xFFFF 約 32MB 的地址空間
    # 而一般內核大小不會超過此大小(<10MB)，所以可以擺爛！
    # jmp _read_begin

    _read_continue:
      
      # 讀完沒有呢
      movw ax, ds:_bootim_pages
      movw bx, ds:_disk_read
      cmp bx, ax    # if (ds:_bootim_pages < bx)
        je _read_end
        jl _read_remain
        mov ax, 127

      _read_remain:
        sub ax, bx

      _read_begin:
      movw [si + 2], ax

      mov dl, ds:_disk_id # 啓動的磁盤號
      mov ah, 0x42        # 中斷號
      int 0x13

      jc _flag_panic      # 炸了就恐慌

      # 更新結構體
      movw ax, [si + 2]
      addw ds:_disk_read, ax
      addw [si + 4], ax
      addw [si + 8], ax

      # 繼續讀取下一個塊
      jmp _read_continue

    _read_end:
    ret

    _flag_no_bootim:
      jmp _flag_panic

  # 寄存器 AX [AL 驅動器號, AH]
  # 寄存器 BX 目的內存段偏移
  # 寄存器 ES 目的內存段號
  # 寄存器 CX [CL 磁盤起始扇區號, CH 讀取扇區數量]
  _func_read_drive:
    mov dl, al      # 中斷參數 驅動器號
    mov al, ch      # 中斷參數 讀取扇區數
    mov ah, 0x02    # 中斷函數
    mov ch, 0x00    # 中斷參數 柱面號
    mov dh, 0x00    # 中斷參數 磁頭號

    int 0x13          # 調用中斷
    cmp ah, 0x00      # 是否成功
      jnz _flag_panic

    xor ax, ax
    ret

  # 加載全局描述符表
  _func_load_gdt:
    lgdt ds:[_GDT_HEADER] # 加載GDT
    mov ax, 0x0000
  ret

  # 進入保護模式
  _func_entry_pmode:
    xor eax, eax

    cli               # 關閉中斷
    
    in al, 0x92       # 使用快速 A20 門
    or al, 2          # 啓用 A20 綫
    out 0x92, al

    mov eax, cr0      # 啓用保護
    or al, 1
    mov cr0, eax

  ret

  _flag_panic:
  lea ax, _msg_newline
  call _func_print
  lea ax, _msg_error
  call _func_print
  hlt

.data
  _msg_newline: .asciz "\r\n"
  _msg_error: .asciz "something went error, panic."
  _msg_booting: .asciz "booting..."

  _disk_id:
    .byte 0

  _disk_lba_desc:
    .8byte 0
    .8byte 0

  _disk_lba_block:
    .2byte 0

  _disk_read:
    .2byte 0

  _bootim_pages:
    .2byte 0

# 全局描述符表
.align 4
_GDT_HEADER:
  .2byte _GDT_ENTRIES_END - _GDT_ENTRIES  # GDT Size
  .4byte _GDT_ENTRIES                     # GDT Base

_GDT_ENTRIES:
  _GDT_NULL:
    .2byte 0x0000   # limit low
    .2byte 0x0000   # base low
    .byte  0x00     # base middle
    .byte  0x00     # access type
    .byte  0x00     # limit high, flags
    .byte  0x00     # base high

  _GDT_CODE32:
    # Base  0x00000000
    # Limit 0x000FFFFF
    # Access 1(Pr) 00(Privl) 1(S) 1(Ex) 0(DC) 1(RW) 1(Ac)
    # Flag   1(Gr) 1(Sz) 0(Null) 0(Null)
    .2byte 0xFFFF   # limit low
    .2byte 0x0000   # base low
    .byte  0x00     # base middle
    .byte  0x9A     # access type
    .byte  0xCF     # limit high, flags
    .byte  0x00     # base high

  _GDT_DATA:
    # Base  0x00000000
    # Limit 0x000FFFFF
    # Access 1(Pr) 00(Privl) 1(S) 0(Ex) 0(DC) 1(RW) 1(Ac)
    # Flag   1(Gr) 1(Sz) 0(Null) 0(Null)
    .2byte 0xFFFF   # limit low
    .2byte 0x0000   # base low
    .byte  0x00     # base middle
    .byte  0x93     # access type
    .byte  0xCF     # limit high, flags
    .byte  0x00     # base high

  _GDT_VIDEO:
_GDT_ENTRIES_END:
