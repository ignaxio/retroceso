//+------------------------------------------------------------------+
//|                                              Distancia 4h en m30 |
//|                                                    Ignacio Farre |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Ignacio Farre"
#property link      ""
#property version   "2.00"
#property strict

#define MAGIC  20

//--- input parameters
input int      apt_media_1=20;// Media 1
input int      apt_media_2=200;// Media 2
//input int      apt_tamano_barra_minimo=80;// Tamaño de barra minimo
input int      apt_porcentaje_minimo=20;// Porcentaje minimo de revote
input int      apt_porcentaje_maximo=40;// Porcentaje máximo de revote
input int      apt_porcentaje_sl=40;// Porcentaje sl
input int      apt_porcentaje_tp=180;// Porcentaje tp
input int      apt_porcentaje_breakeven=5;// Porcentaje breakeven
input int      apt_pips_to_breakeven=1;// Pips para breakeven
input int      apt_porcentaje_move_sl=5;// Porcentaje para movel el sl
input int      apt_tamano_minimo_patron=3;// Tamaño minimo del patron
input string   apt_fine_name="prueba.csv";      // File name

// Varaibles staticas
static int tipo_barra=0; // 0=null, 1=compra, 2=venta
static int file=0; // the file to write
static double spread = 0;// Precio de spread actual
static double tick_value = 0;// Pip minimo del simbolo
static double precio_ask_actual = 0;// precio de compra
static double precio_bid_actual = 0;// Precio de venta
static bool se_ha_operado_en_barra_actual=false;
static bool atraviesa_media=false;
static bool es_barra_actual_mas_grande_que_anterior=false;
static bool es_retorno_correcto=false;
static bool es_barra_actual_correcta=false;
static bool compra_abierta=false;
static bool venta_abierta=false;
static double media_1 = 0;
static double media_2 = 0;
static double cuerpo_barra=0;
static double tamano_patron = 0;
static double precio_low_patron=0;
static double precio_high_patron=0;
static double porcentaje_retorno = 0;
static string orders_to_check[][50];




//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
  return(INIT_SUCCEEDED);
 }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
// Podría coger los datos de ordenes cerradas de aquí
// https://www.mql5.com/en/forum/112700
// OrderSelect(i, Select_by_pos,MODE_HISTORY);



    escribir_fichero();
  //if(ArrayRange(orders_to_check,0)>0) {
	 // for(int i=0;i<ArrayRange(orders_to_check,0);i++) {
	 //   Print("Order numero = " + orders_to_check[i][0]);
	 //   Print("Order type = " + orders_to_check[i][1]);
	 //   Print("Order price = " + orders_to_check[i][2]);
	 //   Print("Order TP = " + orders_to_check[i][3]);
	 //   Print("Order SL = " + orders_to_check[i][4]);
	 //   Print("Order Swap = " + orders_to_check[i][5]);
	 //   Print("Order time = " + orders_to_check[i][6]);
	 // }
  //}

 }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
  //if(Bars<apt_media_4+1)
  //  return;
    
  //escribir_fichero();          
  //check_operaciones_abiertas(); // Vamos a comprobar esto con el array  
  set_breakeven(); // Vamos a comprobar esto con el array
  
  precio_ask_actual = nor1(MarketInfo(Symbol(), MODE_ASK)); // precio de compra
  precio_bid_actual = nor1(MarketInfo(Symbol(), MODE_BID)); // Precio de venta
            
  if(IsNewBarOnChart()) {
  	spread = MarketInfo(Symbol(), MODE_SPREAD)*0.1; 
  	tick_value = MarketInfo(Symbol(),MODE_TICKVALUE); // 0.1  
   	se_ha_operado_en_barra_actual=false;
   	es_barra_actual_correcta=false;
   	porcentaje_retorno=0;
  	
	  media_1=nor1(iMA(NULL,0,apt_media_1,0,MODE_SMA,PRICE_CLOSE,1));
	  media_2=nor1(iMA(NULL,0,apt_media_2,0,MODE_SMA,PRICE_CLOSE,1));
	  
	  set_tipo_barra_y_cuerpo_barra(); 
	  atraviesa_media = check_atraviesa_media();
	  es_barra_actual_mas_grande_que_anterior = check_barra_anterior_mas_grande_que_anterior();
	  
	  if(atraviesa_media && es_barra_actual_mas_grande_que_anterior) {
	  	es_barra_actual_correcta=true;
	  }
  }
  
  
  
  // TODO: Escribir array multidimensional con datos de entradas, así tendremos mas control de todo...
  
  
  // TODO: No esta entrando en todos los patrones, sobre todo las ventas...............................................................................................
  // Depurar bien
  // TODO: meter un porcentaje para mover SL por los puntos, empezandop por breakeven
  // Lo primero es que haga las entradas correctas
  // Cuando haga las entradas correctas, nos ponemos con el TP
  // Cuando haga entradas correctas podemos meter mas filtros para tener un porcentaje de acierto mas alto en entradas.
  
  
  // controlar el orderModify() cuando lo modifique una vez ya no tiene que modificar mas........................................
  
  
  
  
  
  // El servidor tiene una hora adelantado las 15:00 en el servidor son las 16:00
  if(Hour()>=9) {
     if(es_barra_actual_correcta && !se_ha_operado_en_barra_actual) {
   		//Ya tenemos nuestra barra, ahora hay que ver el retroceso que se crea.
   		set_new_porcentaje_retorno();
   		es_retorno_correcto = is_porcentaje_retorno_correcto();		
   	  if(es_retorno_correcto) {
   	  	if(tipo_barra==1 && precio_bid_actual>precio_high_patron) {
   	  		// Compra
   	  		compra(get_tp(), get_sl());
   	  	} else if(tipo_barra==2 && precio_bid_actual<precio_low_patron) {
   	  		// Venta
   	  		venta(get_tp(), get_sl());
   	  	}	  
   	  }
     }
  }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
void set_datos_basicos_to_array(int order_id) {	
	if(OrderSelect(order_id, SELECT_BY_TICKET) && OrderMagicNumber() == MAGIC) {
		if(ArrayRange(orders_to_check,0)>0) {
	 		for(int i=0;i<ArrayRange(orders_to_check,0);i++) {
	 			if(orders_to_check[i][0] == (string)order_id) {
	 				orders_to_check[i][1] = (string)OrderType(); //OrderNumber
					orders_to_check[i][2] = (string)OrderOpenPrice(); //OrderOpenPrice
					orders_to_check[i][3] = (string)OrderTakeProfit(); //OrderTakeProfit
					orders_to_check[i][4] = (string)OrderStopLoss(); //OrderStopLoss
					orders_to_check[i][5] = (string)OrderSwap(); //OrderSwap
					orders_to_check[i][6] = (string)OrderOpenTime(); //OrderOpenTime
					orders_to_check[i][7] = (string)nor2(tamano_patron); //tamano_patron
					orders_to_check[i][8] = (string)nor2(precio_low_patron); //precio_low_patron
					orders_to_check[i][9] = (string)nor2(precio_high_patron); //precio_high_patron
					orders_to_check[i][10] = (string)nor2(porcentaje_retorno); //porcentaje_retorno
					
	 			}
	 		}
	 	}
	}
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
int get_tamano_patron_from_array(int order_id) {	
   int tamano = 0;
	if(ArrayRange(orders_to_check,0)>0) {
 		for(int i=0;i<ArrayRange(orders_to_check,0);i++) {
 			if(orders_to_check[i][0] == (string)order_id) {
 			   tamano = StrToInteger(orders_to_check[i][7]);
 			}
 		}
 	}
	return tamano;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
void set_breakeven() {	
	compra_abierta=false;
	venta_abierta=false;
  if(OrdersTotal()>0) {
    for(int i = OrdersTotal()-1; i >= 0; i--) {    
      // Compras m1
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MAGIC && OrderType() == OP_BUY && OrderStopLoss() < OrderOpenPrice()) {
        // Vamos a ver si podemos colocar el breakeven
        // Tenemos que coger los pip reales con el pordentaje del breakeven
        // Cogemos del array la entrada 
        
        
        int tamano_patron_local = get_tamano_patron_from_array(OrderTicket());
         double pips = (apt_porcentaje_breakeven*tamano_patron_local* 1.)/100;
        
	    //Print("Order tamano_patron = " + (string)tamano_patron_local);
	    //Print("Order pips = " + (string)pips);
        
        
        if(precio_bid_actual>(OrderOpenPrice()+pips)) {
	        double sl = OrderOpenPrice()+apt_pips_to_breakeven;
	        bool Check_modify = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,Orange);
					if(Check_modify==false) {
						Alert("OrderSelect failed");
						// Aquí añadimos primer modify a la orden en el array
						// set_breakeven_done(OrderTicket());
						
						
						
						break;
					} 
        }
      } 
      // Ventas m1
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MAGIC && OrderType() == OP_SELL && OrderStopLoss() > OrderOpenPrice()) {
      
      
        int tamano_patron_local = get_tamano_patron_from_array(OrderTicket());
         double pips = (apt_porcentaje_breakeven*tamano_patron_local* 1.)/100;
//      
//	    Print("Order tamano_patron = " + (string)tamano_patron_local);
//	    Print("Order pips = " + (string)pips);
      
       	if(precio_ask_actual<(OrderOpenPrice()-pips)) {
	        double sl = OrderOpenPrice()-apt_pips_to_breakeven;
	        bool Check_modify = OrderModify(OrderTicket(),OrderOpenPrice(),sl,OrderTakeProfit(),0,Orange);
					if(Check_modify==false) {
						Alert("OrderSelect failed");
						break;
					} 
        }
      }
    }
  }
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
void check_operaciones_abiertas() {	
	compra_abierta=false;
	venta_abierta=false;
  if(OrdersTotal()>0) {
    for(int i = OrdersTotal()-1; i >= 0; i--) {    
      // Compras m1
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MAGIC && OrderType() == OP_BUY) {
        //compra_abierta=true;
        // Vamos a ver si podemos colocar el breakeven
        double precio_entrada = OrderOpenPrice();
        
      } 
      // Ventas m1
      if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MAGIC && OrderType() == OP_SELL) {
        //venta_abierta=true;
      }
    }
  }
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
void set_new_porcentaje_retorno() {
	double porcentaje_retorno_actual = get_porcentaje_rebote_actual();
	
	if(porcentaje_retorno_actual>porcentaje_retorno) {
		porcentaje_retorno = porcentaje_retorno_actual;
	}
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
bool is_porcentaje_retorno_correcto() {
	bool result = false;
	
  if(porcentaje_retorno<apt_porcentaje_maximo && porcentaje_retorno>apt_porcentaje_minimo) {
  	result = true;
  }
  return result;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
double get_sl() {
  double sl = 0;
  double tamano = get_tamano_by_porcentaje_patron(apt_porcentaje_sl); 
  if(tipo_barra==1) {
  	sl = precio_high_patron-tamano;
  }else if(tipo_barra==2) {
  	sl = precio_low_patron+tamano;  
  }
  return sl;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
double get_tp() {
  double tp = 0;
  double tamano = get_tamano_by_porcentaje_patron(apt_porcentaje_tp);   
  if(tipo_barra==1) {
  	tp = precio_high_patron+tamano;
  }else if(tipo_barra==2) {
  	tp = precio_low_patron-tamano;  
  }
  return tp;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
double get_tamano_by_porcentaje_patron(double porcentaje) {
  double tamano = (porcentaje*tamano_patron)/100;
  return tamano;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
double get_porcentaje_rebote_actual() {
  double porcentaje = 0;
  double tamano_actual = 0;
  // Compras
  if(tipo_barra==1) {  	
	  tamano_actual = precio_bid_actual-precio_low_patron;  
  }else if(tipo_barra==2) {
	  tamano_actual = precio_high_patron-precio_bid_actual;    
  }
  porcentaje = 100-((tamano_actual*100)/tamano_patron); 
  return porcentaje;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion de compra                                                                |
//+------------------------------------------------------------------+
bool compra(double tp, double sl) {
  bool check_order = false;
  int order_id = 0;
  double lots = get_lots();
  if(check_podemos_operar(lots)) {
  	double order_tp = tp+spread;
  	double order_sl = sl-spread;
    order_id = OrderSend(Symbol(),OP_BUY,lots,Ask,10,order_sl,order_tp,"shoot",MAGIC,0,Green);
    if(!order_id) {
      Print("Order send error ",GetLastError());
    } else {  
    	//Print("Se ha abierto la entrada de compra " + (string)order_id);   
    	se_ha_operado_en_barra_actual=true;
    	//compra_abierta=true;
    	
    	ArrayResize(orders_to_check,ArrayRange(orders_to_check,0)+1);
      orders_to_check[ArrayRange(orders_to_check,0)-1][0] = (string)order_id; //OrderNumber
      set_datos_basicos_to_array(order_id);
      
    }
  }
  return check_order;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion de compra                                                                |
//+------------------------------------------------------------------+
bool venta(double tp, double sl) {
  bool check_order = false;
  int order_id = 0;
  double lots = get_lots();
  if(check_podemos_operar(lots)) {
  	double order_tp = tp-spread;
  	double order_sl = sl+spread;
    order_id = OrderSend(Symbol(),OP_SELL,lots,Bid,10,order_sl,order_tp,"shoot",MAGIC,0,Green);
    if(!order_id) {
      Print("Order send error ",GetLastError());
    } else {  
    	//Print("Se ha abierto la entrada de venta " + (string)order_id);     
    	se_ha_operado_en_barra_actual=true;
    	//venta_abierta=true;
    	
    	ArrayResize(orders_to_check,ArrayRange(orders_to_check,0)+1);
      orders_to_check[ArrayRange(orders_to_check,0)-1][0] = (string)order_id; //OrderNumber
      set_datos_basicos_to_array(order_id);
      
    }
  }
  return check_order;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que checkea si hay operaciones abieras                                                                |
//+------------------------------------------------------------------+
double get_lots() {
  double lots = false;    
  //double availableMarginCall = AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);  
  double lots_to_call = (AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL))/MarketInfo(Symbol(),MODE_MARGINREQUIRED);
  
    
  return NormalizeDouble(lots_to_call*0.95,Digits);
  //return 0.1;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que checkea si hay operaciones abieras                                                                |
//+------------------------------------------------------------------+
bool check_podemos_operar(double lots) {
  bool result = false;    
//  //double availableMarginCall = AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);  
//  //double lots_to_call = (AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL))/MarketInfo(Symbol(),MODE_MARGINREQUIRED);
//    
//  // Implementar aquí abailable margin mejor %%%%%
  if((AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL))/MarketInfo(Symbol(),MODE_MARGINREQUIRED)>lots) {
     result = true;  
  }  
  return result;
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que normalñiza doubles con 2 decimales                                                       |
//+------------------------------------------------------------------+
double nor2(double value_to_normalize) { 
  return NormalizeDouble(value_to_normalize,2);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que normalñiza doubles con 1 decimales                                                       |
//+------------------------------------------------------------------+
double nor1(double value_to_normalize) { 
  return NormalizeDouble(value_to_normalize,1);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que normalñiza doubles con 0 decimales                                                       |
//+------------------------------------------------------------------+
double nor0(double value_to_normalize) { 
  return NormalizeDouble(value_to_normalize,0);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que devuelve true si hay una nueva barra                                                                 |
//+------------------------------------------------------------------+
bool IsNewBarOnChart() {
  bool new_candle = false;
  static datetime lastbar;
  datetime curbar = (datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);
  
  if(lastbar != curbar) {
    lastbar = curbar;
    new_candle = true;
  }
  return new_candle;
 }
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
bool check_atraviesa_media() {
  bool result = false;
  if(precio_low_patron<media_1 && precio_high_patron>media_1) {
  	result=true;
  }
  if(precio_low_patron<media_2 && precio_high_patron>media_2) {
  	result=true;
  }
  //return result;
  // No vamos a incluir el atraviesa media
  return true;
 }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
bool check_barra_anterior_mas_grande_que_anterior() {
  bool result = false;
  //Print("cuerpo_barra = " + (string)cuerpo_barra);
  if(cuerpo_barra>apt_tamano_minimo_patron) {    
		// Medimos la barra anterior
	  double open_barra_anterior = Open[2];
	  double close_barra_anterior = Close[2];
	  double cuerpo_barra_anterior = 0;
	  
	  if(open_barra_anterior>close_barra_anterior) {
	  	// Barra bajista
	  	cuerpo_barra_anterior = open_barra_anterior-close_barra_anterior;    
	  } else {
	  	// Barra alcista
	  	cuerpo_barra_anterior = close_barra_anterior-open_barra_anterior;    
	  }	  
	  // Comparamos la barra
	  if(cuerpo_barra_anterior<cuerpo_barra) {
	  	result=true;
	  }
  }
  return result;
 }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
void set_tipo_barra_y_cuerpo_barra() {  
	double open_barra = Open[1];
  double close_barra = Close[1];
  
  precio_high_patron = High[1];
  precio_low_patron = Low[1];  
  
  if(open_barra>close_barra && !venta_abierta) {
  	// Barra bajista  
  	cuerpo_barra = open_barra-close_barra;  
  	tipo_barra=2;
	  if(High[2]>High[1] && High[2]>precio_high_patron) {
	  	precio_high_patron = High[2];
		  if(High[3]>High[2] && High[3]>precio_high_patron) {
		  	precio_high_patron = High[3];
			  if(High[4]>High[3] && High[4]>precio_high_patron) {
			  	precio_high_patron = High[4];
				  if(High[5]>High[4] && High[5]>precio_high_patron) {
				  	precio_high_patron = High[5];
				  }
			  }
		  }
	  } 
  } else if(open_barra<close_barra && !compra_abierta) {
  	// Barra alcista
  	cuerpo_barra = close_barra-open_barra;  
  	tipo_barra=1; 
	  if(Low[2]<Low[1] && Low[2]<precio_low_patron) {
	  	precio_low_patron = Low[2];	  	 
		  if(Low[3]<Low[2] && Low[3]<precio_low_patron) {
		  	precio_low_patron = Low[3];
			  if(Low[4]<Low[3] && Low[4]<precio_low_patron) {
			  	precio_low_patron = Low[4];
				  if(Low[5]<Low[4] && Low[5]<precio_low_patron) {
				  	precio_low_patron = Low[5];
				  }
			  }
		  }
	  } 
  }  
  tamano_patron = precio_high_patron-precio_low_patron;
 }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Funcion que retorna el procentaje de rebote                                                               |
//+------------------------------------------------------------------+
void escribir_fichero() {	

	// mirar ejemplo https://docs.mql4.com/files/filewrite


	 //int file_handle=FileOpen(InpDirectoryName+"//"+apt_fine_name,FILE_READ|FILE_WRITE|FILE_CSV);
	 int file_handle=FileOpen(apt_fine_name,FILE_READ|FILE_WRITE|FILE_CSV);
   if(file_handle!=INVALID_HANDLE) {
      PrintFormat("%s file is available for writing",apt_fine_name);
      PrintFormat("File path: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH));
      //--- first, write the number of signals
      //FileWrite(file_handle,4);
      //--- write the time and values of signals to the file
      //for(int i=0;i<sign_size;i++)
      	//FileWrite(file_handle,"hola ficherito","escribo mas");
      	
     	
      FileWrite(file_handle,
      "Order numero",
      "Order type",
      "Order price",
      "Order TP",
      "Order SL",
      "Order Swap",
      "Order time",
      "tamano_patron",
      "precio_low_patron",
      "precio_high_patron",
      "porcentaje_retorno"
      );
            
      
      if(ArrayRange(orders_to_check,0)>0) {
	  		for(int i=0;i<ArrayRange(orders_to_check,0);i++) {
	  			FileWrite(file_handle,
	  			orders_to_check[i][0],
	  			orders_to_check[i][1],
	  			orders_to_check[i][2],
	  			orders_to_check[i][3],
	  			orders_to_check[i][4],
	  			orders_to_check[i][5],
	  			orders_to_check[i][6],
	  			orders_to_check[i][7],
	  			orders_to_check[i][8],
	  			orders_to_check[i][9],
	  			orders_to_check[i][10]
	  			);
	  		}
      }
      	
      	    	
      	
      	
      	
      //--- close the file
      FileClose(file_handle);
      PrintFormat("Data is written, %s file is closed",apt_fine_name);
   } else {
      PrintFormat("Failed to open %s file, Error code = %d",apt_fine_name,GetLastError());
   }
 }
//+------------------------------------------------------------------+
