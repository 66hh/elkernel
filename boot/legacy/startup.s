.intel_syntax noprefix

.text
  .global _start
  .code16

  _start:

  # 清除寄存器
  # 不清除會導致在各個仿真器/虛擬機上行爲不同
  xor ax, ax
  mov ds, ax
  mov di, ax

  movb ds:_disk_id, dl # 驅動器

  mov ah, 0x08
  int 0x13

  mov dl, cl
  and dl, 0x3f
  and cx, 0xffc0

  lea bx, _disk_info
  movb [bx + 0], dh  # 磁頭數量
  movb [bx + 1], dl  # 扇區數量
  movw [bx + 2], cx  # 柱面數量

  # 重置顯示器
  call _func_reset_screen

  # 加載程序主體部分
  call _func_load_bootim

  # 加載全局描述符表
  lgdt ds:[_GDT_HEADER]

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
  # 加載內核入口偏移
  xchg bx, bx
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
  _func_load_bootim:

    # 先讀取 bootim 所在的扇區，並解析
    lea si, _lba_dap
    movw [si + 4], 0x0000    # 偏移
    movw [si + 6], 0x07e0    # 段
    movw [si + 8], 1         # LBA48 低32位 (bootim 在第二扇區)
    movw ax, 1               # 讀取 1 扇區
    call _func_read_drive

    # 判斷幻數 ELKERNEL
    movw ax, ds:0x7e00
    movw bx, ds:0x7e02
    movw cx, ds:0x7e04
    movw dx, ds:0x7e06
      cmp ax, 0x4c45 # EL
        jnz _flag_missing_bootim
      cmp bx, 0x454b # KE
        jnz _flag_missing_bootim
      cmp cx, 0x4e52 # RN
        jnz _flag_missing_bootim
      cmp dx, ax # EL
        jnz _flag_missing_bootim

    # 打印版本字符串
    mov ax, ds:0x7e20
    call _func_print
    call _func_print_newline

    # 好的 那把整個內核全部請進來吧 (?
    # 因爲僅靠 LBA48 的低16位
    # 我們就能尋址至多 512B * 0xFFFF 約 32MB 的地址空間
    # 而一般內核大小不會超過此大小(<10MB)，所以可以擺爛！
    lea si, _lba_dap
    movw [si + 4], 0x0000     # 偏移
    movw [si + 6], 0x0800     # 段
    movw [si + 8], 2          # LBA48 低32位 (內核在第3扇區)
    movw ax, ds:0x7e10        # 0x7e10 爲 bootim 中定義內核的頁數
    call _func_read_drive
    ret

  _func_read_drive:
    movw ds:_read_pages, 0
    movw ds:_total_pages, ax

    # 是否爲軟盤啓動
    movb dl, ds:_disk_id
    test dl, dl
    jz _read_begin_chs

    # movb [si], 0x10        # 大小
    # movb [si + 1], 0x00    # 保留
    # movw [si + 2], 127     # 要讀取的扇區數
    # movw [si + 4], 0x0000  # 偏移
    # movw [si + 6], 0x0800  # 段
    # movw [si + 8], 2       # LBA48 低32位 (內核在第3扇區)
    # movw [si + 10], 0      # LBA48 低32位
    # movw [si + 12], 0      # LBA48 高16位

    _read_continue_lba:
      
      # 讀完沒有呢
      movw ax, ds:_total_pages
      movw bx, ds:_read_pages
      cmp bx, ax    # if (_read_pages <= _total_pages)
        je _read_end

        sub ax, bx
        cmp ax, 127
          jl _read_begin_lba # if ( (_total_pages - _read_pages) < 127)
          mov ax, 127

      _read_begin_lba:
        movw [si + 2], ax

        mov dl, ds:_disk_id   # 啓動的磁盤號
        mov ah, 0x42          # 中斷號
        int 0x13

        jc _flag_disk_failure # 炸了就恐慌

        # 更新結構體
        movw ax, [si + 2]
        addw ds:_read_pages, ax
        addw [si + 4], ax
        addw [si + 8], ax

      # 繼續讀取下一個塊
      jmp _read_continue_lba

    _read_begin_chs:

      # Todo
      jmp $

    _read_end:
    ret

  _flag_missing_bootim:
    lea ax, _msg_missing_bootim
    jmp _flag_panic

  _flag_disk_failure:
    lea ax, _msg_disk_failure
    jmp _flag_panic

  _flag_panic:
    mov bx, ax
    lea ax, _msg_newline
    call _func_print

    mov ax, bx
    call _func_print
    hlt

.data
  _msg_newline: .asciz "\r\n"
  _msg_error: .asciz "something went error, panic."
  _msg_disk_failure: .asciz "disk failure."
  _msg_missing_bootim: .asciz "missing bootim."
  _msg_booting: .asciz "booting..."

  _disk_id:
    .byte 0

  _disk_info:
    .byte 0  # heads
    .byte 0  # sectors
    .2byte 0 # cylinders

  _lba_dap:
    .byte 16 # 長度
    .byte 0
    .2byte 0
    .4byte 0
    .8byte 0

  _total_pages:
    .2byte 0

  _read_pages:
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
