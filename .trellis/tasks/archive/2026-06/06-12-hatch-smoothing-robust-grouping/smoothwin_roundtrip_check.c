/*------------------------------------------------------------------------------
* smoothwin_roundtrip_check.c : smoothwin配置往返验证
*
*-----------------------------------------------------------------------------*/
#include <stdio.h>
#include "rtklib.h"

/* 验证smoothwin配置加载保存重载 ------------------------------------------------
* 调用RTKLIB系统选项API验证pos1-smoothwin往返保持为30
* args   : none
* return : 0表示验证通过，非0表示加载、保存或重载失败
*-----------------------------------------------------------------------------*/
int main(void)
{
    prcopt_t prcopt;
    solopt_t solopt;
    filopt_t filopt;

    resetsysopts();
    if (!loadopts("smooth30.conf",sysopts)) {
        puts("load_failed");
        return 2;
    }
    getsysopts(&prcopt,&solopt,&filopt);
    printf("loaded=%d\n",prcopt.smoothwin);
    if (prcopt.smoothwin!=30) return 3;

    setsysopts(&prcopt,&solopt,&filopt);
    if (!saveopts("smooth30_roundtrip.conf","w","",sysopts)) {
        puts("save_failed");
        return 4;
    }

    resetsysopts();
    if (!loadopts("smooth30_roundtrip.conf",sysopts)) {
        puts("reload_failed");
        return 5;
    }
    getsysopts(&prcopt,&solopt,&filopt);
    printf("reloaded=%d\n",prcopt.smoothwin);
    return prcopt.smoothwin==30?0:6;
}
