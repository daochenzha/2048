library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity 2048 is
generic(
    divide_500k:integer:=300;--frequency devided by 100, i.e. 500KHZ:2us
    cnt1_value:integer:=5
    );
port(
   clk,reset:in std_logic;
   rs,rw,en:out std_logic;
   data:out integer range 255 downto 0;
   up,do,le,ri:in std_logic
   );
end entity;

architecture behavior of photorom is
component rom IS
	PORT
	(
		address		: IN STD_LOGIC_VECTOR (9 DOWNTO 0);
		clock		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END component;

type word16 is array(0 to 31) of integer range 7 downto 0;

type state is(
     reset_all,
     set_dlnf1,set_dcb,set_ddram1,set_ddram2,write_name,write_begin,over
     );


constant row:word16:=(16#80#,16#81#,16#82#,16#83#,16#84#,16#85#,16#86#,16#87#,16#88#,16#89#,16#8A#,16#8B#,16#8C#,16#8D#,16#8E#,16#8F#,
                       16#90#,16#91#,16#92#,16#93#,16#94#,16#95#,16#96#,16#97#,16#98#,16#99#,16#9A#,16#9B#,16#9C#,16#9D#,16#9E#,16#9F#);


signal pr_state:state;
signal newclk:std_logic; 
signal rom_cnt:std_logic_vector (9 downto 0);
signal rom_data:std_logic_vector (7 downto 0);

signal up_reg,do_reg,le_reg,ri_reg:std_logic;

TYPE matrix_index is array (15 downto 0) of integer range 0 to 11;
TYPE matrix_row is array (3 downto 0) of integer range 0 to 11;
SIGNAL matrix: matrix_index;


attribute preserve: boolean;
attribute preserve of matrix: signal is true; 



begin

process(clk) is
variable num:integer range 0 to divide_500k;
begin
   if(clk'event and clk='1')then
    num:=num+1;
    if(num=divide_500k) then
     num:=0;
    end if;
    if(num<divide_500k/2) then--set duty ratio
     newclk<='0';
    else newclk<='1';
    end if;    
   end if;
end process;

process(newclk,reset,pr_state,up,do,le,ri) is
variable temp:matrix_row;
variable temp_cnt:integer range 0 to 3:=0;
variable temp_matrix:matrix_index;
variable zero_cnt:integer range 0 to 15:=0;
variable rand_cnt:integer range 0 to 15:=0;
variable flag:std_logic:='0';
variable cnt1:integer range 0 to 100*cnt1_value:=0;
variable cnt2:integer range 0 to 1024:=0;
variable row_num:integer range 0 to 33:=0;
VARIABLE int_rand: integer;
begin
   if(reset='0') then
    pr_state<=set_dlnf1;       --set present state as set_dlnf1
    cnt1:=0;
    cnt2:=0;
    row_num:=0;
	en<='0';
    for i in 0 to 15 loop                             
     matrix(i)<=0;                                              
    end loop;
    matrix(0)<=1;
    matrix(1)<=1;
    temp_cnt:=0;
    rand_cnt:=0;
    rom_cnt<=conv_std_logic_vector(matrix(0)*32,10); 
    for i in 0 to 3 loop
      temp(i):=0;
    end loop;
    for i in 0 to 15 loop
      temp_matrix(i):=0;
    end loop;
    zero_cnt:=14;
    elsif(newclk'event and newclk='1') then

 case pr_state is
   when reset_all=>
    pr_state<=set_dlnf1;       --set present state as set_dlnf1
    cnt1:=0;
    cnt2:=0;
    row_num:=0;
	en<='0';

	
   when set_dlnf1=>
      cnt1:=cnt1+1;
      if(cnt1<cnt1_value) then
       en<='0';
       rs<='0';       --rs signal
       rw<='0';       --rw signal
      elsif(cnt1<2*cnt1_value) then
       data<=16#34#;    
      elsif(cnt1<20*cnt1_value) then
       en<='1';
      elsif(cnt1=20*cnt1_value) then
       en<='0';
       cnt1:=0;
	   cnt2:=0;
	   pr_state<=set_ddram1; 
      end if;

      when set_dcb=>
      cnt1:=cnt1+1;
      if(cnt1<cnt1_value) then
       en<='0';
      elsif(cnt1<2*cnt1_value) then
       data<=16#01#;     --clear the screen, and set the ponter as 00h:0x01
      elsif(cnt1<20*cnt1_value) then
       en<='1';
      elsif(cnt1=20*cnt1_value) then
       en<='0';
       cnt1:=0;
       pr_state<=set_ddram1; 
      end if;

	when set_ddram1 =>
	  cnt1:=cnt1+1;
      if(cnt1<cnt1_value) then
       en<='0';
       rs<='0';       --rs signal
       rw<='0';       --rw signal
      elsif(cnt1<2*cnt1_value) then
       data<=row(row_num);     
      elsif(cnt1<20*cnt1_value) then
       en<='1';
	  elsif(cnt1=20*cnt1_value) then
	   cnt1:=0;
	   pr_state<=set_ddram2; 				
      end if;
      
  when set_ddram2=>
      cnt1:=cnt1+1;
      if(cnt1<cnt1_value) then
       en<='0';
       rs<='0';       --rs signal
       rw<='0';       --rw signal
      elsif(cnt1<2*cnt1_value) then
      if cnt2<512 then
       data<=16#80#;     
      else
       data<=16#88#;
      end if;
      elsif(cnt1<20*cnt1_value) then
       en<='1';
      elsif(cnt1=20*cnt1_value) then
       en<='0';
       cnt1:=0;
	   pr_state<=write_name; 
      end if;	
       
  when write_name=>
	  cnt1:=cnt1+1;
      if cnt1<1*cnt1_value then
       en<='0';
       rs<='1';                   ------------tell the chip we gonna send data to it
       rw<='0';
      elsif cnt1<2*cnt1_value then
       if cnt2 mod 16 < 8 then
       data<=conv_integer(rom_data);        ------------push data
       else
       data<=16#00#;
       end if;
      elsif cnt1<20*cnt1_value then
       en<='1';                 -----tell the chip that data are ready so that it can "accept" the data
      elsif cnt1=21*cnt1_value then   
       en<='0';       
       cnt2:=cnt2+1;
	
	   cnt1:=0;
	   if cnt2 mod 16=0 then
        if cnt2=1024 then
			cnt2:=0;
			pr_state<=write_begin;
		else

	    if cnt2<513 then
	        cnt2:=cnt2+496;
			pr_state<=set_ddram1;
		else
	        row_num:=row_num+1;
            cnt2:=cnt2-512;
			pr_state<=set_ddram1;
	    end if;        		
		end if;
       end if;
        rom_cnt<=conv_std_logic_vector(matrix(((cnt2/16)/16)*4 + (cnt2 mod 16)/2)*32 + (2*((cnt2/16) mod 16)+(cnt2 mod 2)),10); 

      end if;
      
    when write_begin =>
      cnt1:=cnt1+1;
      if(cnt1<cnt1_value) then
       en<='0';
       rs<='0';       
       rw<='0';       
      elsif(cnt1<2*cnt1_value) then
       data<=16#36#;     
      elsif(cnt1<20*cnt1_value) then
       en<='1';
      elsif(cnt1=20*cnt1_value) then
       en<='0';
       cnt1:=0;
	   cnt2:=0;
	   pr_state<=over; 
      end if;    

    when over=>
      up_reg<=up;
      do_reg<=do;
      le_reg<=le;
      ri_reg<=ri;
    if(le_reg='1' and le='0') then
    flag:='0';
    for i in 0 to 15 loop
      temp_matrix(i):=matrix(i);
    end loop;
    for i in 0 to 3 loop
      for j in 0 to 3 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt+1;
        end if;
      end loop;
      for k in 0 to 3 loop
        if temp_matrix(i*4+k) /= temp(k) then
          flag:='1';
          temp_matrix(i*4+k):=temp(k);
        end if;
        temp(k):=0;
      end loop;
      temp_cnt:=0;
    end loop;

    for i in 0 to 3 loop
      for j in 0 to 2 loop
        if temp_matrix(i*4+j) /= 0 and temp_matrix(i*4+j) = temp_matrix(i*4+j+1) then
          temp_matrix(i*4+j):=temp_matrix(i*4+j)+1;
          temp_matrix(i*4+j+1):=0;
          zero_cnt:=zero_cnt-1;
          flag:='1';
        end if;
      end loop;
    end loop;

    for i in 0 to 3 loop
      for j in 0 to 3 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt+1;
        end if;
      end loop;
      for k in 0 to 3 loop
        temp_matrix(i*4+k):=temp(k);
        temp(k):=0;
      end loop;
      temp_cnt:=0;
    end loop;

    if zero_cnt /= 0 and flag='1' then
    int_rand := 101 mod zero_cnt;
    for i in 0 to 15 loop
      if temp_matrix(i)=0 then
        if int_rand = rand_cnt then
          temp_matrix(i):=1;
        end if;
        rand_cnt:=rand_cnt+1;
      end if;
    end loop;
    rand_cnt:=0;
    end if;

    for i in 0 to 15 loop
      matrix(i)<=temp_matrix(i);
    end loop;
      

  pr_state<=reset_all;

  elsif(ri_reg='1' and ri='0') then
    flag:='0';
    for i in 0 to 15 loop
      temp_matrix(i):=matrix(i);
    end loop;
    for i in 0 to 3 loop
      temp_cnt:=3;
      for j in 3 downto 0 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt-1;
        end if;
      end loop;
      for k in 0 to 3 loop
        if temp_matrix(i*4+k) /= temp(k) then
          flag:='1';
          temp_matrix(i*4+k):=temp(k);
        end if;
        temp(k):=0;
      end loop;

    end loop;

    for i in 0 to 3 loop
      for j in 3 downto 1 loop
        if temp_matrix(i*4+j) /= 0 and temp_matrix(i*4+j) = temp_matrix(i*4+j-1) then
          temp_matrix(i*4+j):=temp_matrix(i*4+j)+1;
          temp_matrix(i*4+j-1):=0;
          zero_cnt:=zero_cnt-1;
          flag:='1';
        end if;
      end loop;
    end loop;

    for i in 0 to 3 loop
      temp_cnt:=3;
      for j in 3 downto 0 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt-1;
        end if;
      end loop;
      for k in 0 to 3 loop
        temp_matrix(i*4+k):=temp(k);
        temp(k):=0;
      end loop;

    end loop;

    if zero_cnt /= 0 and flag='1' then
    int_rand := 101 mod zero_cnt;
    for i in 0 to 15 loop
      if temp_matrix(i)=0 then
        if int_rand = rand_cnt then
          temp_matrix(i):=1;
        end if;
        rand_cnt:=rand_cnt+1;
      end if;
    end loop;
    rand_cnt:=0;
    end if;

    for i in 0 to 15 loop
      matrix(i)<=temp_matrix(i);
    end loop;


  pr_state<=reset_all;

  elsif(up_reg='1' and up='0') then
    flag:='0';
    for i in 0 to 15 loop
      temp_matrix(i):=matrix(i);
    end loop;
    for j in 0 to 3 loop
      for i in 0 to 3 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt+1;
        end if;
      end loop;
      for k in 0 to 3 loop
        if temp_matrix(k*4+j) /= temp(k) then
          flag:='1';
          temp_matrix(k*4+j):=temp(k);
        end if;
        temp(k):=0;
      end loop;
      temp_cnt:=0;
    end loop;

    for j in 0 to 3 loop
      for i in 0 to 2 loop
        if temp_matrix(i*4+j) /= 0 and temp_matrix(i*4+j) = temp_matrix((i+1)*4+j) then
          temp_matrix(i*4+j):=temp_matrix(i*4+j)+1;
          temp_matrix((i+1)*4+j):=0;
          zero_cnt:=zero_cnt-1;
          flag:='1';
        end if;
      end loop;
    end loop;

    for j in 0 to 3 loop
      for i in 0 to 3 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt+1;
        end if;
      end loop;
      for k in 0 to 3 loop
        temp_matrix(k*4+j):=temp(k);
        temp(k):=0;
      end loop;
      temp_cnt:=0;
    end loop;

    if zero_cnt /= 0 and flag='1' then
    int_rand := 101 mod zero_cnt;
    for i in 0 to 15 loop
      if temp_matrix(i)=0 then
        if int_rand = rand_cnt then
          temp_matrix(i):=1;
        end if;
        rand_cnt:=rand_cnt+1;
      end if;
    end loop;
    rand_cnt:=0;
    end if;

    for i in 0 to 15 loop
      matrix(i)<=temp_matrix(i);
    end loop;

  pr_state<=reset_all;

  elsif(do_reg='1' and do='0') then
    flag:='0';
    for i in 0 to 15 loop
      temp_matrix(i):=matrix(i);
    end loop;
    for j in 0 to 3 loop
      temp_cnt:=3;
      for i in 3 downto 0 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt-1;
        end if;
      end loop;
      for k in 0 to 3 loop
        if temp_matrix(k*4+j) /= temp(k) then
          flag:='1';
          temp_matrix(k*4+j):=temp(k);
        end if;
        temp(k):=0;
      end loop;
    end loop;

    for j in 0 to 3 loop
      for i in 3 downto 1 loop
        if temp_matrix(i*4+j) /= 0 and temp_matrix(i*4+j) = temp_matrix((i-1)*4+j) then
          temp_matrix(i*4+j):=temp_matrix(i*4+j)+1;
          temp_matrix((i-1)*4+j):=0;
          zero_cnt:=zero_cnt-1;
          flag:='1';
        end if;
      end loop;
    end loop;

    for j in 0 to 3 loop
      temp_cnt:=3;
      for i in 3 downto 0 loop
        if temp_matrix(i*4+j) /= 0 then
          temp(temp_cnt) := temp_matrix(i*4+j);
          temp_cnt:=temp_cnt-1;
        end if;
      end loop;
      for k in 0 to 3 loop
        temp_matrix(k*4+j):=temp(k);
        temp(k):=0;
      end loop;
    end loop;

    if zero_cnt /= 0 and flag='1' then
    int_rand := 101 mod zero_cnt;
    for i in 0 to 15 loop
      if temp_matrix(i)=0 then
        if int_rand = rand_cnt then
          temp_matrix(i):=1;
        end if;
        rand_cnt:=rand_cnt+1;
      end if;
    end loop;
    rand_cnt:=0;
    end if;

    for i in 0 to 15 loop
      matrix(i)<=temp_matrix(i);
    end loop;

  pr_state<=reset_all;

  else
    null;
  end if;

    when others=>
      en<='Z';
      rs<='Z';
      rw<='Z';
      cnt1:=0;
      cnt2:=0;  
    end case; 
   end if;
   end process;
rom_inst : rom PORT MAP (
		address	 => rom_cnt,
		clock	 => clk,
		q	 => rom_data
	);

end architecture;