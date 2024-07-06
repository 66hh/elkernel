﻿#include "eint.h"
#include "ekrnln.h"

/**
 *  @brief 数值转换 - 到整数
 *
 *  调用格式： 〈整数型〉 到整数 （通用型 待转换的文本或数值） - 系统核心支持库->数值转换
 *  英文名称：ToInt
 *  返回包含于文本内的整数值，文本中是一个适当类型的数值，支持全角书写方式。本命令也可用作将其他类型的数据转换为整数。本命令为初级命令。
 *  参数<1>的名称为“待转换的文本或数值”，类型为“通用型（all）”。
*/
INT krnln_fnToInt(PMDATA_INF pRetData, UINT32 uArgCount, PMDATA_INF pArgInf) {
  switch (pArgInf->m_dtDataType) {

    case SDT_BYTE:
      return pArgInf->m_byte;

    case SDT_SHORT:
      return pArgInf->m_short;

    case SDT_INT:
    case SDT_BOOL:
    case SDT_SUB_PTR:
      return pArgInf->m_int;

    case SDT_FLOAT:
      return (INT)pArgInf->m_float;

    case SDT_DOUBLE:
      return (INT)pArgInf->m_double;

    case SDT_INT64:
      return (INT)pArgInf->m_int64;
    default:
      return 0;
  }
}
