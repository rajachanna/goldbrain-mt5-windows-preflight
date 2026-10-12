//+------------------------------------------------------------------+
//| GoldBrain MetaQuotes Demo XAUUSD REAL TICK export - read only    |
//| Uses historical server ticks via CopyTicksRange, never generates |
//| simulated ticks and never sends trading orders.                 |
//+------------------------------------------------------------------+
#property strict
input string InpSymbol = "XAUUSD";
input datetime InpFromUTC = D'2026.10.09 00:00:00';
input datetime InpToUTC   = D'2026.10.09 00:10:00';
input int InpChunkMinutes = 5;
input int InpMaxChunkTicks = 300000;
void OnStart()
  {
   if(InpToUTC<=InpFromUTC || InpChunkMinutes<1 || InpChunkMinutes>60)
     {
      Print("INVALID_DATE_RANGE_OR_CHUNK"); return;
     }
   if(!SymbolSelect(InpSymbol,true))
     {
      Print("SYMBOL_UNAVAILABLE ",InpSymbol," last_error=",GetLastError()); return;
     }
   long seen=0;
   datetime step=(datetime)(InpChunkMinutes*60);
   MqlTick ticks[];
   for(datetime from=InpFromUTC;from<InpToUTC;from+=(int)step)
     {
      datetime to=(datetime)MathMin((long)InpToUTC,(long)from+(long)step);
      ulong fromms=(ulong)from*1000;
      ulong toms=(ulong)to*1000-1;
      ResetLastError();
      int n=CopyTicksRange(InpSymbol,ticks,COPY_TICKS_ALL,fromms,toms);
      int err=GetLastError();
      if(n<0 || n>InpMaxChunkTicks)
        {
         Print("TICK_SYNC_ERROR_OR_TOO_MANY ",(long)fromms, " n=",n," err=",err);
         return;
        }
      Print("RAW_TICKS ",(long)fromms," ",(long)toms," n=",n," err=",err);
      if(n==0) continue;
      string name=StringFormat("GoldBrain_%s_%I64d_%I64d.csv",InpSymbol,
                               (long)fromms,(long)toms);
      int f=FileOpen(name,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
      if(f==INVALID_HANDLE)
        {
         Print("FILE_OPEN_ERROR ",name," err=",GetLastError());return;
        }
      FileWrite(f,"timestamp_utc_ms","bid","ask","last","volume","flags");
      long prev=-1;
      int invalid=0;
      for(int i=0;i<n;i++)
        {
         MqlTick x=ticks[i];
         if((long)x.time_msc<prev || x.bid<=0 || x.ask<x.bid)
           {
            invalid++;
            continue;
           }
         prev=(long)x.time_msc;
         FileWrite(f,(long)x.time_msc,DoubleToString(x.bid,8),
                   DoubleToString(x.ask,8),DoubleToString(x.last,8),
                   (long)x.volume,(int)x.flags);
        }
      FileFlush(f);
      FileClose(f);
      if(invalid>0)
        {
         Print("RAW_QUALITY_VIOLATION ",name," invalid=",invalid,
               " aborted; do not train");return;
        }
      seen+=n;
      Print("SAVED_RAW_TICKS ",name," ",n);
     }
   Print("GOLDBRAIN_MT5_EXPORT_COMPLETE ticks=",seen,
         " symbol=",InpSymbol," read_only=true");
  }
