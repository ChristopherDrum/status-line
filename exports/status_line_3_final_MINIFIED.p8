pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
_engine_version="3.0"
_program_counter,_interrupt,game_id=0,nil,0
story_loaded,full_color=false,false
punc=".,!?_#'\"/\\-:()"
load_message="𝘥𝘳𝘢𝘨 𝘪𝘯 𝘢\n𝘻3/4/5/8 𝘨𝘢𝘮𝘦\n𝘰𝘳 𝘢 split1 𝘧𝘪𝘭𝘦\n𝘵𝘰 𝘴𝘵𝘢𝘳𝘵 𝘱𝘭𝘢𝘺𝘪𝘯𝘨"
message=load_message
function rehydrate_menu_vars()
local raw_strings="screen_types`1`ega,0,7`b&w,6,0`green,138,131`amber,9,128`blue,12,129`oldlcd,131,129`plasma,8,130`invert,0,6/scroll_speeds`3`slow,7`medium,5`fast,4`faster,2`fastest,0/clock_types`1`24-hour,24`12-hour,12/cursor_types`1`block,▮`square,■`bar,|`under,_`dotted,⁶:150a150a15000000"
local strings=split(raw_strings,"/")
for str in all(strings)do
local def,menu=split(str,"`"),{}
menu["default"]=def[2]
local values={}
for i=3,#def do
add(values,split(def[i]))
end
menu["values"]=values
_𝘦𝘯𝘷[def[1]]=menu
end
end
function rehydrate_ops()
local raw_strings="_zero_ops,_rtrue,_rfalse,_print,_print_rtrue,_nop,_save,_restore,_restart,_ret_pulled,_pop_catch,_quit,_new_line,_show_status,_btrue,_nop,_btrue/_short_ops,_jz,_get_sibling,_get_child,_get_parent,_get_prop_len,_inc,_dec,_print_addr,_call_f,_remove_obj,_print_obj,_ret,_jump,_print_paddr,_load,_not_call_p/_long_ops,_nop,_je,_jl,_jg,_dec_jl,_inc_jg,_jin,_test,_or,_and,_test_attr,_set_attr,_clear_attr,_store,_insert_obj,_loadw,_loadb,_get_prop,_get_prop_addr,_get_next_prop,_add,_sub,_mul,_div,_mod,_call_f,_call_p,_set_color,_throw/_var_ops,_call_f,_storew,_storeb,_put_prop,_read,_print_char,_print_num,_random,stack_push,_pull,_split_screen,_set_window,_call_f,_erase_window,_erase_line,_set_cursor,_get_cursor,_set_text_style,_nop,_output_stream,_input_stream,_sound_effect,_read_char,_scan_table,_not,_call_p,_call_p,_tokenise,_encode_text,_copy_table,_print_table,_check_arg_count/_ext_ops,_save,_restore,_log_shift,_art_shift,_set_font,_nop,_nop,_nop,_nop,_deny_undo,_deny_undo,_print_unicode,_nop,_nop,_nop"
local strings=split(raw_strings,"/")
for str in all(strings)do
local def=split(str)
_𝘦𝘯𝘷[def[1]]={}
local str={}
for j=2,#def do
add(_𝘦𝘯𝘷[def[1]],_𝘦𝘯𝘷[def[j]])
add(str,def[j])
end
add(_𝘦𝘯𝘷[def[1]],str)
end
end
function rehydrate_mem_addresses(raw_strings)
local strings=split(raw_strings)
for str in all(strings)do
local def=split(str,"=")
_𝘦𝘯𝘷[def[1]]=tonum(def[2])
end
end
function in_set(val,set)
for i=1,#set do
if set[i]==val do return true end
end
return false
end
function tohex(value)
return sub(tostr(value,3),3,6)
end
function wait_for_any_key()
local keypress=nil
while keypress==nil do
if stat(30)do
poke(24368,1)
keypress=stat(31)
end
flip()
end
return keypress
end
function build_menu(name,dval,table)
local var=dget(dval)
if var==0do var=table.default end
dset(dval,var)
local item_name,right_dec,left_dec=unpack(table.values[var]),var<#table.values and"•"or"",var>1and"•"or""
local item_str=name..": "..left_dec..item_name..right_dec
menuitem(dval+1,item_str,function(b)if b<112do if b&1<=0do var+=1end if b&1>0do var-=1end var=mid(1,var,#table.values)dset(dval,var)build_menu(name,dval,table)end end)
end
_memory,_memory_start_state,_memory_bank_size={{}},{},16384
call_type={none=0,func=1,proc=2,intr=3}
frame={pc=0,call=0,args=0}
function frame:new()
local obj={
stack={},
vars={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
}
return setmetatable(obj,{__index=self})
end
function frame:stack_push(val)
add(self.stack,val)
end
function frame:stack_pop()
if#self.stack==0do return nil end
return deli(self.stack)
end
function top_frame()
return _call_stack[#_call_stack]
end
function stack_top()
local st=top_frame().stack
return st[#st]
end
function set_stack_top(val)
local st=top_frame().stack
st[#st]=val
top_frame().stack=st
end
function _restart()
for i=1,#_memory_start_state do
_memory[1][i]=_memory_start_state[i]
end
flush_volatile_state()
initialize_game()
end
function clear_all_memory()
_memory,_memory_start_state={{}},{}
flush_volatile_state()
end
function flush_volatile_state()
_call_stack={}
_program_counter=0
_interrupt=nil
_current_state=""
max_input_length=0
separators,_main_dict={},{}
story_loaded=false
end
function stack_push(zword)
top_frame():stack_push(zword)
end
function stack_pop()
return top_frame():stack_pop()
end
function call_stack_push()
if#_call_stack>0do top_frame().pc=_program_counter end
add(_call_stack,frame:new())
end
function call_stack_pop()
deli(_call_stack)
_program_counter=top_frame().pc
end
function abbr_address(index)
return zword_to_zaddress(get_zword(_abbr_table_mem_addr+(index>>>15))<<1)
end
function set_var(value,_var_byte,indirect)
local var_byte=_var_byte or get_zbyte()
if var_byte==0do
if indirect do set_stack_top(value)else stack_push(value)end
elseif var_byte<16do
local zaddr=_local_var_table_mem_addr+(var_byte>>>16)
top_frame().vars[zaddr<<16]=value
else
local zaddr=_global_var_table_mem_addr+(var_byte-16>>>15)
set_zbyte(zaddr,value>>>8)
set_zbyte(zaddr+.00002,value)
end
end
function get_var(_var_byte,indirect)
local var_byte,var_address=_var_byte or get_zbyte()
if var_byte==0do
var_address=_stack_mem_addr
elseif var_byte<16do
var_address=_local_var_table_mem_addr+(var_byte>>>16)
else
var_address=_global_var_table_mem_addr+(var_byte-16>>>15)
end
return get_zword(var_address,indirect)
end
function zword_to_zaddress(zaddress,_is_packed)
local is_packed=_is_packed or false
zaddress>>>=16
if is_packed==true do zaddress<<=_zm_packed_shift end
return zaddress
end
function zaddress_at_zaddress(zaddress,is_packed)
return zword_to_zaddress(get_zword(zaddress),is_packed)
end
function get_dword(zaddress,indirect)
local zaddress=zaddress or _program_counter
if zaddress<10do
local bank,za=(zaddress&15)+1,(zaddress<<16>>>2)+1
local index,cell=za&-1,(za&.99999)<<2
return _memory[bank][index],bank,index,cell
end
if zaddress>=_local_var_table_mem_addr do
local index=zaddress<<16
local var=top_frame().vars[index]
return var,nil,index
end
if zaddress==_stack_mem_addr do
if indirect do return stack_top()end
return stack_pop()
end
end
function get_zbyte(zaddress)
if not zaddress do
zaddress=_program_counter
_program_counter+=.00002
end
local dword,_,_,cell=get_dword(zaddress)
if zaddress<10do dword>>>=-((cell<<3)-8)end
return dword&255
end
function get_zbytes(zaddress,num_bytes)
if not zaddress do return end
local bytes={}
for i=0,num_bytes-1do
add(bytes,get_zbyte(zaddress))
zaddress+=.00002
end
return bytes
end
function set_zbyte(zaddress,_byte)
local byte=_byte&255
if zaddress==_stack_mem_addr do
stack_push(byte)
elseif zaddress<10do
local dword,bank,index,cell=get_dword(zaddress)
local offset=cell<<3
local filter=~(-256>>>offset)
dword&=filter
byte>>>=offset-8
dword|=byte
_memory[bank][index]=dword
end
end
function set_zbytes(zaddress,bytes)
for i=1,#bytes do
set_zbyte(zaddress,bytes[i])
zaddress+=.00002
end
end
function get_zword(zaddress,indirect)
if not zaddress do
zaddress=_program_counter
_program_counter+=.00004
end
local dword,_,_,cell=get_dword(zaddress,indirect)
if zaddress<10do
dword<<=cell<<3
if cell==3do
local dwordb=get_dword(zaddress+.00002)
dword|=dwordb>>>8
end
end
return dword&-1
end
function set_zword(zaddress,_zword,indirect)
local zword=_zword&-1
if zaddress==_stack_mem_addr do
if indirect do set_stack_top(zword)else stack_push(zword)end
elseif zaddress<10do
set_zbyte(zaddress,zword>>>8)
set_zbyte(zaddress+.00002,zword)
elseif zaddress>=_local_var_table_mem_addr do
top_frame().vars[zaddress<<16]=zword
end
end
function zobject_attributes_byte_bit(index,attribute_id)
if index==0do return 0end
local address,byte_index,attr_bit=_zobject_address+((index-1)*_zm_object_entry_size>>>16),flr(attribute_id>>3),attribute_id%8
address+=byte_index>>>16
return get_zbyte(address),attr_bit,address
end
function zobject_has_attribute(index,attribute_id)
if index==0do return 0end
local attr_byte,attr_bit=zobject_attributes_byte_bit(index,attribute_id)
local attr_check=128>>attr_bit
return attr_byte&attr_check==attr_check
end
function zobject_set_attribute(index,attribute_id,val)
if index<1or val>1do return end
local attr_byte,attr_bit,address=zobject_attributes_byte_bit(index,attribute_id)
attr_byte&=~(128>>attr_bit)
attr_byte|=val<<7-attr_bit
set_zbyte(address,attr_byte)
end
zparent,zsibling,zchild=0,1,2
function zfamily_address(index,family_member)
local address,attr_size,member_size=_zobject_address+((index-1)*_zm_object_entry_size>>>16),.0001,.00004
if _zm_version==3do attr_size,member_size=.00007,.00002end
address+=attr_size+family_member*member_size
return address
end
function zobject_family(index,family_member)
if index==0do return 0end
local address=zfamily_address(index,family_member)
if _zm_version==3do return get_zbyte(address)end
return get_zword(address)
end
function zobject_set_family(index,family_member,family_index)
if index==0do return 0end
local address=zfamily_address(index,family_member)
if _zm_version==3do set_zbyte(address,family_index)else set_zword(address,family_index)end
end
function zobject_prop_table_address(index)
local offset=_zm_version==3and.00011or.00019
local prop_table_address=_zobject_address+((index-1)*_zm_object_entry_size>>>16)+offset
local zword=get_zword(prop_table_address)
return zword_to_zaddress(zword)
end
function zobject_name(obj_index)
local prop_addr=zobject_prop_table_address(obj_index)
local text_length=get_zbyte(prop_addr)
if text_length>0do return get_zstring(prop_addr+.00002)end
return""
end
function extract_prop_len_num(local_addr)
local len_num_byte=get_zbyte(local_addr)
if len_num_byte==0do return 0,0,0end
local len,num,offset=0,0,1
if _zm_version==3do
len=(len_num_byte>>>5&7)+1
num=len_num_byte&31
else
num=len_num_byte&63
if len_num_byte&128==0do
len=(len_num_byte>>>6&1)+1
else
len_num_byte=get_zbyte(local_addr+.00002)
len=len_num_byte&63
if len==0do len=64end
offset=2
end
end
return len,num,offset
end
target_addr,target_next=0,1
function zobject_search_properties(obj,prop,target)
if obj==0do return 0end
local prop_addr=zobject_prop_table_address(obj)
local text_length=get_zbyte(prop_addr)
prop_addr+=.00002+(text_length>>>15)
local prop_len,prop_num,offset=extract_prop_len_num(prop_addr)
if prop==0do
if target==target_next and prop_num>0do return prop_num end
return 0
end
local get_next=false
while prop_num>0do
if prop_num==prop do
if target==target_addr do
return prop_addr+(offset>>>16),prop_len
else
get_next=true
end
end
prop_addr+=prop_len+offset>>>16
prop_len,prop_num,offset=extract_prop_len_num(prop_addr)
if get_next==true do return prop_num end
end
return 0
end
function zobject_get_prop(index,property)
local function zobject_default_property(property)
assert(property<=_zm_object_property_count,"𝘦𝘳𝘳: default object property "..property)
local address=_object_table_mem_addr+(property-1>>>15)
return get_zword(address)
end
if index==0do return 0end
local prop_data_addr,len=zobject_search_properties(index,property,target_addr)
if prop_data_addr==0do return zobject_default_property(property)end
if len==1do return get_zbyte(prop_data_addr)end
if len==2do return get_zword(prop_data_addr)end
return 0
end
function zobject_set_prop(index,property,value)
if index==0do return 0end
local prop_data_addr,len=zobject_search_properties(index,property,target_addr)
if len==1do set_zbyte(prop_data_addr,value&255)end
if len==2do set_zword(prop_data_addr,value&-1)end
end
function get_zstring(zaddress,_is_dict)
local is_dict,end_found,zchars=_is_dict or false,false,{}
while end_found==false do
local zword=get_zword(zaddress)
for shift=10,0,-5do
add(zchars,zword>>>shift&31)
end
if zaddress do zaddress+=.00004end
end_found=zword&32768==32768
if _is_dict==true do
end_found=#zchars==_zm_dictionary_word_length
end
end
return zscii_to_p8scii(zchars)
end
local zchar_tables={
"     abcdefghijklmnopqrstuvwxyz",
"     𝘢𝘣𝘤𝘥𝘦𝘧𝘨𝘩𝘪𝘫𝘬𝘭𝘮𝘯𝘰𝘱𝘲𝘳𝘴𝘵𝘶𝘷𝘸𝘹𝘺𝘻",
"      \n0123456789"..punc}
function zscii_to_p8scii(zchars,_casestyle)
local casestyle,zscii,zscii_decode,abbr_code,zstring,active_table=_casestyle or nil,nil,false,nil,"",1
for i=1,#zchars do
local zchar=zchars[i]
if zscii_decode==true do
if zscii==nil do
zscii=zchar<<5
else
zscii|=zchar
local c=chr(zscii)
if casestyle do c=case_setter(c,casestyle)end
zstring..=c
zscii_decode=false
zscii=nil
active_table=1
end
elseif abbr_code do
local index=(abbr_code-1<<5)+zchar
local abbr_address=abbr_address(index)
abbr_code=nil
zstring..=get_zstring(abbr_address)
active_table=1
elseif zchar==0do
zstring..=" "
active_table=1
elseif zchar<4do
abbr_code=zchar
elseif zchar==4do
active_table=2
elseif zchar==5do
active_table=3
elseif zchar==6and active_table==3do
zscii_decode=true
elseif zchar>31do
local c=chr(zchar)
if casestyle do c=case_setter(c,casestyle)end
zstring..=c
active_table=1
else
local lookup_string=zchar_tables[active_table]
zstring..=lookup_string[zchar]
active_table=1
end
end
return zstring
end
function load_instruction()
local op_table,op_code,operands=nil,0,{}
local function extract_operand_by_type(op_type)
if op_type==0do return get_zword()end
if op_type==1do return get_zbyte()end
if op_type==2do return get_var()end
return nil
end
local function extract_operands(info,count)
for i=count-1,0,-1do
local op_type=info>>>i*2&3
local operand=extract_operand_by_type(op_type)
if operand==nil do break end
add(operands,operand)
end
end
local pc,op_definition=_program_counter,get_zbyte()
local op_form=op_definition>>>6&255
if op_definition==190do op_form=190end
if op_form<=1do
op_table=_long_ops
op_code=op_definition&31
operands={get_zbyte(),get_zbyte()}
if op_definition&64==64do operands[1]=get_var(operands[1])end
if op_definition&32==32do operands[2]=get_var(operands[2])end
elseif op_form==190and _zm_version>=5do
op_table=_ext_ops
op_code=get_zbyte()
extract_operands(get_zbyte(),4)
elseif op_form==2do
op_table=_short_ops
op_code=op_definition&15
local op_type=(op_definition&48)>>>4
operands={extract_operand_by_type(op_type)}
if op_type==3do
op_table=_zero_ops
operands={}
end
elseif op_form==3do
op_table=op_definition&32==0and _long_ops or _var_ops
op_code=op_definition&31
local type_information,op_count
if _zm_version>3and(op_definition==236or op_definition==250)do
type_information,op_count=get_zword(),8
else
type_information,op_count=get_zbyte(),4
end
extract_operands(type_information,op_count)
if op_table==_long_ops and#operands==1and op_code>1do get_zbyte()end
end
return op_table[op_code+1],operands
end
story_id,disk=nil,0
function load_story_file()
local function flush()
while stat(120)do serial(2048,17152,1024)end
end
if disk==0do clear_all_memory()end
local in_header,header_processed=false,false
while stat(120)do
local chunk=serial(2048,17152,1024)
for j=0,chunk-1,4do
local a,b,c,d=peek(17152+j,4)
local dword=a<<8|b|c>>>8|d>>>16
if header_processed==false and in_header==false and dword&-0x.01==0xdeca.ff do
if d-disk~=1do flush()message=load_message return end
in_header,disk=true,d
else
if in_header do
story_id=story_id or dword
if dword~=story_id do flush()end
in_header,header_processed=false,true
else
add(_memory[#_memory],dword)
end
end
if#_memory[#_memory]==_memory_bank_size do add(_memory,{})end
end
end
if disk==1do
message="\n\np𝘭𝘦𝘢𝘴𝘦 𝘥𝘳𝘢𝘨 𝘪𝘯\n𝘵𝘩𝘦 split2 𝘧𝘪𝘭𝘦..."
else
story_id,disk,is_split=nil,0,false
initialize_game()
end
end
_result=set_var
function _branch(should_branch)
local branch_arg=get_zbyte()
local reverse_arg,big_branch,offset=branch_arg&128==0,branch_arg&64==0,branch_arg&63
if reverse_arg==true do should_branch=not should_branch end
if big_branch==true do
if offset>31do offset-=64end
offset<<=8
offset+=get_zbyte()
end
if should_branch==true do
if offset==0or offset==1do
_ret(offset)
else
offset>>=16
_program_counter+=offset-.00004
end
end
end
function _load(var)
_result(get_var(var,true))
end
function _store(var,a)
_result(a,var,true)
end
function _loadw(baddr,n)
local addr=zword_to_zaddress(baddr+n*2)
_result(get_zword(addr))
end
function _storew(baddr,n,zword)
local addr=zword_to_zaddress(baddr+n*2)
set_zword(addr,zword)
end
function _loadb(baddr,n)
local addr=zword_to_zaddress(baddr+n)
_result(get_zbyte(addr))
end
function _storeb(baddr,n,zbyte)
local addr=zword_to_zaddress(baddr+n)
set_zbyte(addr,zbyte)
end
function _pull(var)
_result(stack_pop(),var,true)
end
function _scan_table(a,baddr,n,byte)
local base_addr,byte=zword_to_zaddress(baddr),byte or 130
local getter,entry_len,should_branch=byte&128==128and get_zword or get_zbyte,(byte&127)>>16,false
for i=1,n do
if getter(base_addr)==a do
should_branch=true
break
end
base_addr+=entry_len
end
if should_branch==false do base_addr=0end
_result(base_addr<<16)
_branch(should_branch)
end
function _copy_table(baddr1,baddr2,s)
local from=zword_to_zaddress(baddr1)
if baddr2==0do
for i=0,s-1do
set_zbyte(from+(i>>>16),0)
end
else
local to,st,en,step=zword_to_zaddress(baddr2),s-1,0,-1
if s<0or from>to do
s=abs(s)
st,en,step=0,s-1,1
end
for i=st,en,step do
local offset=i>>>16
local byte=get_zbyte(from+offset)
set_zbyte(to+offset,byte)
end
end
end
function _add(a,b)
_result(a+b)
end
function _sub(a,b)
_result(a-b)
end
function _mul(a,b)
_result(a*b)
end
function _div(a,b,help)
local d=a/b
d=d<0and ceil(d)or flr(d)
if help do return d else _result(d)end
end
function _mod(a,b)
_result(a-_div(a,b,true)*b)
end
function _inc(var)
local zword=get_var(var)+1
_result(zword,var)
end
function _dec(var)
local zword=get_var(var)-1
_result(zword,var)
end
function _inc_jg(var,s)
local zword=get_var(var)+1
_result(zword,var)
_branch(zword>s)
end
function _dec_jl(var,s)
local zword=get_var(var)-1
_result(zword,var)
_branch(zword<s)
end
function _or(a,b)
_result(a|b)
end
function _and(a,b)
_result(a&b)
end
function _not(a)
_result(~a)
end
function _log_shift(a,t)
_result(flr(a<<t))
end
function _art_shift(s,t)
_result(s>>-t)
end
function _jz(a)
_branch(a==0)
end
function _je(a,b1,b2,b3)
if b1 do
if a==b1 or a==b2 or a==b3 do
_branch(true)
else
_branch(false)
end
else
_program_counter+=.00002
end
end
function _jl(s,t)
_branch(s<t)
end
function _jg(s,t)
_branch(s>t)
end
function _jin(obj,n)
local parent=zobject_family(obj,zparent)
local should_branch=parent==n or n==0and parent==nil
_branch(should_branch)
end
function _test(a,b)
_branch(a&b==b)
end
function _jump(s)
_program_counter+=s-2>>16
end
function _call_f(...)
_call_fp(call_type.func,...)
end
function _call_p(...)
_call_fp(call_type.proc,...)
end
function _call_fp(type,raddr,a1,a2,a3,a4,a5,a6,a7)
if raddr==0do
if type~=call_type.func do return end
_result(0)
else
local r=zword_to_zaddress(raddr,true)
local l=get_zbyte(r)
r+=.00002
local fpc,pc=top_frame().pc,_program_counter
call_stack_push()
if type==call_type.intr do _call_stack[#_call_stack-1].pc=0end
if _zm_version>=5do top_frame().pc=r end
local a_vars={a1,a2,a3,a4,a5,a6,a7}
local n=min(l,#a_vars)
for i=1,l do
if i<=n do
zword=a_vars[i]
else
zword=_zm_version<5and get_zword(r)or 0
end
set_zword(_local_var_table_mem_addr+(i>>>16),zword)
r+=.00004
end
if _zm_version<5do top_frame().pc=r end
top_frame().call=type
top_frame().args=n
_program_counter=top_frame().pc
if type==call_type.intr do
while _program_counter~=0do
local func,operands=load_instruction()
func(unpack(operands))
end
top_frame().pc=fpc
_program_counter=pc
return stack_pop()
end
end
end
function _ret(a)
local call=top_frame().call
call_stack_pop()
if call==call_type.intr do
stack_push(a)
elseif call==call_type.func do
_result(a)
end
end
function _rtrue()
_ret(1)
end
function _rfalse()
_ret(0)
end
function _ret_pulled()
_ret(stack_top())
end
function _check_arg_count(n)
_branch(top_frame().args>=n)
end
function _catch()
_result(#_call_stack)
end
function _throw(a,fp)
while#_call_stack>fp do
call_stack_pop()
end
_ret(a)
end
function _get_family_member(obj,fam)
local member=zobject_family(obj,fam)
if not member do member=0end
_result(member)
if fam~=zparent do _branch(member~=0)end
end
function _get_sibling(obj)
_get_family_member(obj,zsibling)
end
function _get_child(obj)
_get_family_member(obj,zchild)
end
function _get_parent(obj)
_get_family_member(obj,zparent)
end
function _remove_obj(obj)
if obj==0do return end
local original_parent=zobject_family(obj,zparent)
if original_parent~=0do
local next_child,next_sibling=zobject_family(original_parent,zchild),zobject_family(obj,zsibling)
if next_child==obj do
zobject_set_family(original_parent,zchild,next_sibling)
else
while next_child~=0do
if zobject_family(next_child,zsibling)==obj do
zobject_set_family(next_child,zsibling,next_sibling)
next_child=0
else
next_child=zobject_family(next_child,zsibling)
end
end
end
end
zobject_set_family(obj,zparent,0)
zobject_set_family(obj,zsibling,0)
end
function _insert_obj(obj1,obj2)
if obj1==0or obj2==0do return end
_remove_obj(obj1)
local first_child=zobject_family(obj2,zchild)
zobject_set_family(obj2,zchild,obj1)
zobject_set_family(obj1,zparent,obj2)
zobject_set_family(obj1,zsibling,first_child)
end
function _test_attr(obj,attr)
_branch(zobject_has_attribute(obj,attr))
end
function _set_attr(obj,attr)
zobject_set_attribute(obj,attr,1)
end
function _clear_attr(obj,attr)
zobject_set_attribute(obj,attr,0)
end
function _put_prop(obj,prop,a)
zobject_set_prop(obj,prop,a)
end
function _get_prop(obj,prop)
_result(zobject_get_prop(obj,prop))
end
function _get_prop_addr(obj,prop)
local addr=zobject_search_properties(obj,prop,target_addr)
_result(addr<<16)
end
function _get_next_prop(obj,prop)
local next_prop=zobject_search_properties(obj,prop,target_next)
_result(next_prop)
end
function _get_prop_len(baddr)
local len=0
if baddr~=0do
local addr=zword_to_zaddress(baddr-1)
local byte=get_zbyte(addr)
if _zm_version>3do
if byte&128==128do
addr-=.00002
end
end
len=extract_prop_len_num(addr)
end
_result(len)
end
function _split_screen(lines)
flush_line_buffer(1)
flush_line_buffer(0)
local win0,win1=windows[0],windows[1]
win1.h=min(_zm_screen_height,lines)
local p_height=win1.h*6+origin_y
win1.screen_rect={0,origin_y,128,p_height+1}
win0.h=max(0,_zm_screen_height-lines)
win0.screen_rect={0,p_height+1,128,128}
if win1.z_cursor[2]>win1.h do set_z_cursor(1,1,1)end
win0.z_cursor[2]+=lines
if win1.h>win0.z_cursor[2]do set_z_cursor(0,1,1)end
if _zm_version==3and lines>0do _erase_window(1)end
end
function _set_window(win)
flush_line_buffer()
active_window=win
if win==1do _set_cursor(1,1)end
end
function _set_cursor(lin,col)
if _zm_version>3and active_window==0do return end
flush_line_buffer()
if active_window==1and lin>windows[1].h do
windows[1].h=min(_zm_screen_height,lin)
local p_height=windows[1].h*6+origin_y
windows[1].screen_rect={0,origin_y,128,p_height+1}
end
set_z_cursor(active_window,col,lin)
end
function _get_cursor(baddr)
baddr=zword_to_zaddress(baddr)
local zx,zy=unpack(windows[active_window].z_cursor)
if active_window==1and windows[1].fakex do zx=windows[1].fakex end
set_zword(baddr,zy)
set_zword(baddr+.00004,zx)
end
function _set_color(byte0,byte1)
if byte0>0do
current_fg=byte0>1and byte0
or get_zbyte(_default_fg_color_addr)
end
if byte1>0do
current_bg=byte1>1and byte1
or get_zbyte(_default_bg_color_addr)
end
update_text_colors()
end
function _set_font(n)
_result(0)
end
function _output_stream(_n,baddr,w)
if _n==0do return end
local n,on_off=abs(_n),_n>0
if n==1do
screen_stream=on_off
elseif n==2do
trans_stream=on_off
local p_flag=get_zbyte(_peripherals_header_addr)
if trans_stream==true do p_flag|=1else p_flag&=254end
set_zbyte(_peripherals_header_addr,p_flag)
elseif n==3do
mem_stream=on_off
if mem_stream==true do
local addr=zword_to_zaddress(baddr)
add(mem_stream_addr,addr)
set_zword(addr,0)
else
deli(mem_stream_addr)
mem_stream=#mem_stream_addr>0
end
elseif n==4do
script_stream=on_off
end
end
function _input_stream(n)
end
function _read(baddr1,baddr2,time,raddr)
if not _interrupt do
flush_line_buffer()
z_text_buffer=baddr1
z_parse_buffer=baddr2
if raddr do
z_timed_interval=time\10
z_timed_routine=raddr
z_current_time=stat(94)*60+stat(95)
end
_show_status()
preloaded=false
_interrupt=capture_line
else
preloaded=false
current_input,visible_input="",""
z_text_buffer,z_parse_buffer,_interrupt=nil,nil,nil
z_timed_interval,z_timed_routine,z_current_time=0,nil,0
if _zm_version>4do _result(baddr1)end
end
end
function _read_char(one,time,raddr)
if not _interrupt do
flush_line_buffer()
if raddr do
z_timed_interval=time\10
z_timed_routine=raddr
z_current_time=stat(94)*60+stat(95)
end
_interrupt=capture_char
else
_interrupt=nil
z_timed_interval,z_timed_routine,z_current_time=0,nil,0
_result(ord(one))
end
end
function _print_char(n)
if n==10do n=13end
if n~=0do output(chr(n))end
end
function _print_unicode(c)
if c>255do c=63end
_print_char(c)
end
function _new_line()
output(chr(13))
end
function _print(string)
local zstring=get_zstring(string)
output(zstring)
end
function _print_rtrue(string)
_print(string)
_new_line()
_rtrue()
end
function _print_addr(baddr,is_packed)
local zaddress=zword_to_zaddress(baddr,is_packed)
_print(zaddress)
end
function _print_paddr(saddr)
_print_addr(saddr,true)
end
function _print_num(s)
output(tostr(s))
end
function _print_obj(obj)
if obj==0do return end
local name=zobject_name(obj)
output(name)
end
function _print_table(baddr,width,_height,_skip)
local skip,height,za,zx,zy=_skip or 0,_height or 1,zword_to_zaddress(baddr),unpack(windows[active_window].z_cursor)
for i=1,height do
local str=""
for j=1,width+skip do
if j<=width do
_print_char(get_zbyte(za))
end
za+=.00002
end
if height>1do
zy+=1
_set_cursor(zy,zx)
end
end
end
function _erase_line(val)
if val==1do
local px,py=unpack(windows[active_window].p_cursor)
rectfill(px,py,128,py+5,current_bg)
end
end
function _erase_window(win)
if win>=0do
local a,b,c,d=unpack(windows[win].screen_rect)
rectfill(a,b,c,d,current_bg)
if win==1do
set_z_cursor(win,1,1)
else
if _zm_version>=5do
set_z_cursor(win,1,1)
else
set_z_cursor(win,1,windows[win].h)
end
end
elseif win==-1do
_split_screen(0)
active_window=0
cls(current_bg)
if _zm_version<5do
set_z_cursor(0,1,windows[0].h)
else
set_z_cursor(0,1,1)
end
elseif win==-2do
cls(current_bg)
end
flip()
if win<=0do
windows[0].buffer={}
lines_shown=0
else
windows[1].buffer={}
end
end
function _sound_effect(number)
if number==1do print"⁷c3"end
if number==2do print"⁷c1"end
end
function _save(did_save)
if _interrupt==nil do
_interrupt=save_game
output('𝘦nter filename (max 30 chars; careful, do 𝘯𝘰𝘵 press "𝘦𝘴𝘤")\n\n>',true)
else
_interrupt=nil
if _zm_version==3do _branch(did_save)else _result(did_save)end
end
end
function _restore(baddr1,n,baddr2)
local rg=restore_game()
if _zm_version==3do
_branch(rg)
else
if rg~=0and n do rg=n end
_result(rg)
end
end
function _deny_undo()
_result(-1)
end
function _nop()
end
function _random(s)
local r=0
if s>0do
r=flr(rnd(s))+1
else
if s==0do s=stat(93)..stat(94)..stat(95)end
srand(s)
end
_result(r)
end
function _quit()
story_loaded=false
end
function _btrue()
_branch(true)
end
function _pop_catch()
if _zm_version<5do stack_pop()else _catch()end
end
function _not_call_p(...)
if _zm_version<5do _not(...)else _call_fp(call_type.proc,...)end
end
function save_game(char)
if char=="\r"do
local filename=current_input.."_"..game_id.."_save"
write_save_state(filename)
reuse_last_line=true
add(windows[active_window].buffer,windows[active_window].last_line)
output(current_input,true)
current_input,visible_input="",""
show_warning=true
local s=_zm_version==3and true or 1
_save(s)
else
process_input_char(char,30)
end
end
function write_save_state(filename)
local d=""
local function dump(num)
d..=dword_to_str(num)
end
dump(tonum(_engine_version))
dump(tonum(game_id.."0000",3))
dump(tonum(_program_counter))
for i=1,_memory_bank_size do
dump(_memory[1][i])
end
dump(#_call_stack)
for i=1,#_call_stack do
local frame=_call_stack[i]
dump(frame.pc)
dump(frame.call)
dump(frame.args)
dump(#frame.stack)
for j=1,#frame.stack do
dump(frame.stack[j])
end
for k=1,16do
dump(frame.vars[k])
end
end
printh(d,filename,true)
end
function restore_game()
output("𝘥rag in a "..game_id.."_save.p8l file or any key to exit.\n",true)
extcmd"folder"
local key_pressed,file_dropped,stop_waiting=false,false,false
while stop_waiting==false do
flip()
if stat(30)do
poke(24368,1)
key_pressed=true
elseif stat(120)do
file_dropped=true
end
stop_waiting=key_pressed or file_dropped
end
if key_pressed==true do
current_input=""
return _zm_version==3and false or 0
end
local temp={}
while stat(120)do
local chunk=serial(2048,17152,4096)
for j=0,chunk-1,8do
local a,b,c,d,e,f,g,h=peek(17152+j,8)
local hex=chr(a)..chr(b)..chr(c)..chr(d)..chr(e)..chr(f)..chr(g)..chr(h)
add(temp,tonum(hex,3))
end
end
local index=1
local save_engine=temp[index]
if save_engine~=tonum(_engine_version)do
output("𝘵his save file requires v"..tostr(save_engine).." of 𝘴tatus 𝘭ine.\n",true)
return _zm_version==3and false or 0
end
index+=1
local save_id=tohex(temp[index],false)
if save_id~=game_id do
output"𝘵his save file appears to be for a different game.\n"
return _zm_version==3and false or 0
end
index+=1
_program_counter=temp[index]
index+=1
for i=1,_memory_bank_size do
_memory[1][i]=temp[index]
index+=1
end
_call_stack={}
local call_stack_length=temp[index]
index+=1
for i=1,call_stack_length do
local frame=frame:new()
frame.pc=temp[index]
frame.call=temp[index+1]
frame.args=temp[index+2]
local stack_length=temp[index+3]
for j=1,stack_length do
add(frame.stack,temp[index+3+j])
end
index+=3+stack_length
for k=1,16do
frame.vars[k]=temp[index+k]
end
add(_call_stack,frame)
index+=17
end
current_input=""
return _zm_version==3and true or 2
end
zchar_map_str=[[	00, 00, 00, 00, 05, 00, 00, 00, 00, 07,
    00, 00, 00, 00, 00, 00, 00, 00, 00, 00,
    00, 00, 00, 00, 00, 00, 00, 00, 00, 00,
    00, 32, 20, 25, 23, 00, 00, 00, 24, 30,
    31, 00, 00, 19, 28, 18, 26, 00, 01, 02,
    03, 04, 05, 06, 07, 08, 09, 29, 00, 00,
    00, 00, 21, 00, 06, 07, 08, 09, 10, 11,
    12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    00, 27, 00, 00, 22, 00, 06, 07, 08, 09,
    10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
    30, 31
]]
zchar_map=split(zchar_map_str)
function reset_io_state()
current_bg,current_fg,current_font=0,15,1
if full_color==true do
current_fg=get_zbyte(_default_fg_color_addr)
current_bg=get_zbyte(_default_bg_color_addr)
end
pal(0,current_bg)
current_text_style=0
text_style_updated=false
text_style,text_colors="",""
font_width=4
window_attributes=0x.0a
emit_rate=0
clock_type,cursor_type=nil,nil
mem_stream,screen_stream,trans_stream,script_stream=false,true,false,false
mem_stream_addr,memory_output={},{}
active_window=0
windows={
[0]={
h=21,
z_cursor={1,21},
p_cursor={0,0},
screen_rect={},
buffer={},
last_line=""
},
{
h=0,
z_cursor={1,1},
p_cursor={0,0},
screen_rect={},
buffer={},
last_line="",
fakex=nil
}
}
if _zm_version>=5do windows[0].z_cursor={1,1}end
origin_y=_zm_version==3and 7or 0
windows[0].h=_zm_screen_height
did_trim_nl,reuse_last_line=false,false
lines_shown=0
z_text_buffer,z_parse_buffer=nil,nil
z_timed_interval,z_timed_routine=0,nil
z_current_time=0
current_input,visible_input="",""
show_warning=true
end
function update_text_colors()
text_colors="ᶜ"..tostr(current_fg,true)[6].."²"..tostr(current_bg,true)[6]
text_style_updated=true
end
function _set_text_style(n)
if n>0do n|=current_text_style end
local inverse=n&1==1and"⁶i"or"⁶-i⁶-b"
if n&4==4and n&2~=2do inverse..="⁶-b"end
local font_shift=(n&2==2or n&4==4)and"ᵉ"or"ᶠ"
font_width=n&2==2and 5or 4
if(game_id=="fc65"or game_id=="91e0")and active_window==1do
if n&4==2do n&=11end
end
set_zbyte(_font_width_units_addr,font_width)
text_style=font_shift..inverse
current_text_style=n
text_style_updated=true
end
function set_z_cursor(_win,_x,_y)
local win=windows[_win]
_x,_y=mid(1,_x,32),mid(1,_y,win.h)
local px,py=flr(_x-1<<2)+1,(_y-1)*6+1
if _zm_version>3and _win==0do py+=1end
local py_offset=_win==0and windows[1].h*6or 0
win.p_cursor={px,py+py_offset+origin_y}
cursor(unpack(win.p_cursor))
win.z_cursor={_x,_y}
end
function memory(str)
if#str==0do return end
local addr=mem_stream_addr[#mem_stream_addr]
local table_len,p8bytes=get_zword(addr),pack(ord(str,1,#str))
set_zbytes(addr+.00004+(table_len>>>16),p8bytes)
set_zword(addr,table_len+#p8bytes)
end
function screen(str)
local win=windows[active_window]
clip(unpack(win.screen_rect))
local zx,zy=unpack(win.z_cursor)
if active_window==0do
if reuse_last_line==false do print"\n"end
rectfill(0,121,128,128,current_bg)
local pixel_count=print("⁶d"..emit_rate..str,1,122)-1
if reuse_last_line==true do
reuse_last_line=false
if pixel_count>128and _interrupt==capture_line do
rectfill(0,121,128,128,current_bg)
print("⁶d"..emit_rate..str,1-(pixel_count-128),122)
end
end
zx=ceil(pixel_count>>2)
zy=win.h
lines_shown+=1
else
local px,py=unpack(win.p_cursor)
local pixel_count=print(str,px,py)-px
zx+=flr(pixel_count>>2)
if did_trim_nl==true do
zx=1
zy+=1
end
end
set_z_cursor(active_window,zx,zy)
flip()
clip()
end
function flush_line_buffer(_w)
local w=_w or active_window
local win=windows[w]
local buffer=win.buffer
if#buffer==0or win.h==0do return end
while#buffer>0do
local str=deli(buffer,1)
if w==0and lines_shown==win.h-1do
screen("⁶i"..text_colors.."          - - 𝘮𝘰𝘳𝘦 - -          ")
reuse_last_line,lines_shown=true,0
wait_for_any_key()
lines_shown=0
end
did_trim_nl=false
if str[-1]=="\n"do
str=sub(str,1,-2)
did_trim_nl=true
end
if w==1do win.fakex=nil end
win.last_line=str
screen(str)
end
end
local break_index=0
function output(str,flush_now)
if mem_stream==true do memory(str)return end
if screen_stream==false do return end
local buffer,current_format=windows[active_window].buffer,text_style..text_colors
local current_line=deli(buffer)
if current_line do
if text_style_updated==true do
current_line..=current_format
text_style_updated=false
end
else
current_line=current_format
end
local cx,cy=cursor(0,-20)
local pixel_len=print(current_line)
cursor(cx,cy)
for i=1,#str do
local char=case_setter(str[i],flipcase)
local c=char
if char~="\n"do pixel_len+=font_width end
if current_text_style&2==2do
if char>=" "do char=chr(ord(char)+96)end
end
current_line..=char
if active_window==0do
if in_set(c," \n:-_;")do break_index=#current_line end
if pixel_len>128or c=="\n"do
if break_index==0do break_index=#current_line-1end
local first,second=unpack(split(current_line,break_index,false))
add(buffer,first)
second=second or""
while second[1]==" "do second=sub(second,2)end
current_line=current_format..second
cx,cy=cursor(0,-20)
pixel_len=print(current_line)
cursor(cx,cy)
break_index=0
end
else
windows[1].fakex=flr(pixel_len>>2)
if c=="\n"do
add(buffer,current_line)
current_line=current_format
flush_line_buffer()
end
end
end
if#current_line>0do add(buffer,current_line)end
if flush_now==true do flush_line_buffer()end
end
function _tokenise(baddr1,baddr2,baddr3,_bit)
local bit,text_buffer,parse_buffer=_bit or 0,zword_to_zaddress(baddr1),zword_to_zaddress(baddr2)
baddr2=parse_buffer
local dict=baddr3==nil and _main_dict or build_dictionary(zword_to_zaddress(baddr3))
text_buffer+=.00002
local num_bytes=255
if _zm_version>=5do
num_bytes=get_zbyte(text_buffer)
text_buffer+=.00002
end
parse_buffer+=.00004
local word,index,token_count,offset="",0,0,_zm_version<5and 0or 1
local function commit_token()
if#word>0do
local word_addr=dict[sub(word,1,_zm_dictionary_word_length)]or 0
if bit>0and word_addr==0do
else
set_zword(parse_buffer,word_addr)
set_zbyte(parse_buffer+.00004,#word)
set_zbyte(parse_buffer+.00005,index+offset)
end
parse_buffer+=.00007
token_count+=1
end
end
for j=1,num_bytes do
local c=get_zbyte(text_buffer)
text_buffer+=.00002
if _zm_version<5and c==0do break end
local char=chr(c)
if char==" "or in_set(char,separators)do
commit_token()
word,index="",0
if char~=" "do
word,index=char,j
commit_token()
word,index="",0
end
else
if index==0do index=j end
word..=char
end
end
commit_token()
set_zbyte(baddr2+.00002,token_count)
end
function _encode_text(baddr1,n,p,baddr2)
if not baddr2 do return end
local zwords,word,count={},0,1
local function commit(v)
word=word<<5|v
if count%3==0do
add(zwords,word)
word=0
end
count+=1
end
local input_addr=zword_to_zaddress(baddr1+p)
local bytes,max_words=get_zbytes(input_addr,n),_zm_version<4and 2or 3
for i=1,max_words*3do
local o=ord(str[i])or 5
if mid(65,o,90)==o do
commit(4)
elseif o==10or
mid(48,o,57)==o or
in_set(str[i],punc)do
commit(5)
end
commit(zchar_map[o])
if#zwords>=max_words do break end
end
zwords[#zwords]|=32768
local out_addr=zword_to_zaddress(baddr2)
for word in all(zwords)do
set_zword(out_addr,word)
out_addr+=.00004
end
end
lowercase,visual_case,flipcase=1,2,3
function case_setter(char,case)
local o=ord(char)
if case==lowercase do
if o>=128and o<=153do
o-=31
elseif o>=65and o<=90do
o+=32
end
elseif case==visual_case do
if o>=97and o<=122do
o-=32
elseif o>=128and o<=153do
o-=31
end
elseif case==flipcase do
if o>=97and o<=122do
o-=32
elseif o>=65and o<=90do
o+=32
elseif o==13do
o=10
end
end
return chr(o)
end
function process_input_char(char,max_length)
if char=="⁸"do
if#current_input>0do
current_input=sub(current_input,1,-2)
visible_input=sub(visible_input,1,-2)
end
elseif char and char~=""and char~="\r"do
if#current_input<max_length do
current_input..=case_setter(char,lowercase)
visible_input..=case_setter(char,visual_case)
end
end
reuse_last_line=true
screen(windows[active_window].last_line..visible_input..cursor_string)
end
function capture_char(char)
cursor_string=" "
capture_input(char)
end
function capture_line(char)
capture_input(char)
end
preloaded=false
function capture_input(char)
lines_shown=0
local win=windows[active_window]
if char do
poke(24368,1)
if _interrupt==capture_char do
_read_char(char)
elseif _interrupt==capture_line do
if _zm_version>=5and preloaded==false do
local text_buffer=zword_to_zaddress(z_text_buffer)
local num_bytes=get_zbyte(text_buffer+.00002)
if num_bytes>0do
local pre=get_zbytes(text_buffer+.00004,num_bytes)
local zstring,flipped,last_line=zscii_to_p8scii(pre,lowercase),zscii_to_p8scii(pre,flipcase),win.last_line
local left,right=unpack(split(last_line,#last_line-num_bytes))
if flipped==right do
win.last_line=left
current_input=zstring
visible_input=right
end
end
preloaded=true
end
if char=="\r"do
reuse_last_line=true
add(win.buffer,win.last_line)
output(current_input,true)
local words,stripped=split(current_input," ",false),""
for w in all(words)do
if#w>0do stripped..=(#stripped==0and""or" ")..w end
end
current_input=stripped
local bytes,text_buffer=pack(ord(current_input,1,#current_input)),zword_to_zaddress(z_text_buffer)
local addr=text_buffer+.00002
if _zm_version>=5do
local num_bytes=get_zbyte(addr)
if preloaded==true do num_bytes=0end
set_zbyte(addr,#bytes+num_bytes)
addr+=.00002+(num_bytes>>>16)
else
add(bytes,0)
end
set_zbytes(addr,bytes)
if z_parse_buffer do _tokenise(z_text_buffer,z_parse_buffer)end
_read(13)
else
if max_input_length==0do max_input_length=get_zbyte(zword_to_zaddress(z_text_buffer))-1end
process_input_char(char,max_input_length)
end
end
else
if active_window==0and _interrupt==capture_line do process_input_char()end
if z_timed_routine do
local current_time=stat(94)*60+stat(95)
if current_time-z_current_time>=z_timed_interval do
local cached_line,timed_response=win.last_line,_call_fp(call_type.intr,z_timed_routine)
if timed_response==1do _read(0)end
if _interrupt==capture_line do win.last_line=cached_line end
flush_line_buffer()
z_current_time=current_time
end
end
end
end
function dword_to_str(dword)
local hex=tostr(dword,3)
return sub(hex,3)
end
function _show_status()
if _zm_version~=3do return end
local obj=get_zword(_global_var_table_mem_addr)
local location,scorea,scoreb,flag,separator=zobject_name(obj),get_zword(_global_var_table_mem_addr+.00004),get_zword(_global_var_table_mem_addr+.00007),get_zbyte(_interpreter_flags_header_addr),"/"
if flag&2==2do
local ampm=""
separator=":"
if clock_type==12do
ampm="a"
if scorea>=12do
ampm="p"
scorea-=12
end
if scorea==0do scorea=12end
end
scoreb=sub("0"..scoreb,-2)..ampm
end
local score=scorea..separator..scoreb
location=sub(location,1,30-#score-2)
local flipped=""
for i=1,#location do
flipped..=case_setter(location[i],flipcase)
end
local spacer_len=32-#location-#score
flipped..=sub("                                ",-spacer_len)..score
print("⁶i"..text_colors..flipped,1,1)
end
function _init()
poke(24365,1)
poke(24374,4)
memcpy(22016,8192,2048)
cartdata"drum_statusline_1"
rehydrate_menu_vars()
build_menu("screen",0,screen_types)
build_menu("scroll",1,scroll_speeds)
build_menu("clock",2,clock_types)
build_menu("cursor",3,cursor_types)
rehydrate_ops()
rehydrate_mem_addresses"_paged_memory_mem_addr=0x0,_dictionary_mem_addr=0x0,_object_table_mem_addr=0x0,_global_var_table_mem_addr=0x0,_static_memory_mem_addr=0x0,_abbr_table_mem_addr=0x0,_dynamic_memory_mem_addr=0x0,_high_memory_mem_addr=0x0,_program_counter_mem_addr=0xc,_local_var_table_mem_addr=0xe,_stack_mem_addr=0xd,_version_header_addr=0x.0000,_interpreter_flags_header_addr=0x.0001,_release_number_header_addr=0x.0002,_paged_memory_header_addr=0x.0004,_program_counter_header_addr=0x.0006,_dictionary_header_addr=0x.0008,_object_table_header_addr=0x.000a,_global_var_table_header_addr=0x.000c,_static_memory_header_addr=0x.000e,_peripherals_header_addr=0x.0010,_serial_code_header_addr=0x.0012,_abbr_table_header_addr=0x.0018,_file_length_header_addr=0x.001a,_file_checksum_header_addr=0x.001c,_interpreter_number_header_addr=0x.001e,_interpreter_version_header_addr=0x.001f,_screen_height_header_addr=0x.0020,_screen_width_header_addr=0x.0021,_screen_width_units_addr=0x.0022,_screen_height_units_addr=0x.0024,_font_height_units_addr=0x.0026,_font_width_units_addr=0x.0027,_default_bg_color_addr=0x.002c,_default_fg_color_addr=0x.002d,_terminating_chars_table_addr=0x.002e,_standard_revision_num_addr=0x.0032,_alt_character_set_addr=0x.0034,_extension_table_addr=0x.0036"
end
function draw_splashscreen()
cls(0)
pal(split"128,130,133,134,5,6,7,8,9,10,11,12,13,14,15",1)
sspr(0,0,128,128,0,0)
print(message,21,66,7)
flip()
end
function setup_palette()
pal()
local st=dget(0)or 1
local mode,fg,bg=unpack(screen_types.values[st])
full_color=mode=="ega"
p=split"0,0,8,139,10,140,136,12,7,6,5,133,14,15"
p[0],p[15]=bg,fg
pal(p,1)
end
function setup_user_prefs()
local er,ct,cur=dget(1)or 3,dget(2)or 1,dget(3)or 1
_,emit_rate=unpack(scroll_speeds.values[er])
_,clock_type=unpack(clock_types.values[ct])
_,cursor_type=unpack(cursor_types.values[cur])
end
cursor_string=" "
function _update60()
if story_loaded==true do
if _interrupt do
cursor_string=stat(95)%2==0and cursor_type or" "
local key=nil
if stat(30)and key==nil do
poke(24368,1)
key=stat(31)
end
if key==nil and _interrupt==capture_char do
if btn(0)do key=chr(131)end
if btn(1)do key=chr(132)end
if btn(2)do key=chr(129)end
if btn(3)do key=chr(130)end
end
_interrupt(key)
else
local _count=0
while _count<180and
_interrupt==nil and
story_loaded==true do
local func,operands=load_instruction()
func(unpack(operands))
_count+=1
end
end
else
if stat(120)do
message="\n\n\ns𝘵𝘰𝘳𝘺 𝘪𝘴 𝘭𝘰𝘢𝘥𝘪𝘯𝘨..."
draw_splashscreen()
load_story_file()
else
if _program_counter~=0do
flush_line_buffer()
screen("⁶i"..text_colors.."       ~ 𝘦𝘯𝘥 𝘰𝘧 𝘴𝘦𝘴𝘴𝘪𝘰𝘯 ~       ")
wait_for_any_key()
clear_all_memory()
message=load_message
end
pal()
draw_splashscreen()
end
end
end
function build_dictionary(addr)
local dict,num_separators={},get_zbyte(addr)
addr+=.00002
local seps=get_zbytes(addr,num_separators)
separators=zscii_to_p8scii(seps)
addr+=num_separators>>>16
local entry_length=get_zbyte(addr)>>>16
addr+=.00002
local word_count=abs(get_zword(addr))
addr+=.00004
for i=1,word_count do
local zstring=get_zstring(addr,true)
dict[zstring]=addr<<16
addr+=entry_length
end
return dict
end
function process_header()
_zm_version=get_zbyte(_version_header_addr)
local i_flag,p_flag=get_zbyte(_interpreter_flags_header_addr),130
if _zm_version<4do
_zm_screen_height=20
_zm_packed_shift=1
_zm_object_property_count=31
_zm_object_entry_size=9
_zm_dictionary_word_length=6
i_flag&=7
i_flag|=32
full_color=false
else
_zm_screen_height=21
_zm_packed_shift=_zm_version<8and 2or 3
_zm_object_property_count=63
_zm_object_entry_size=14
_zm_dictionary_word_length=9
set_zbyte(_interpreter_number_header_addr,6)
set_zbyte(_interpreter_version_header_addr,112)
set_zbyte(_screen_height_header_addr,_zm_screen_height)
set_zbyte(_screen_width_header_addr,32)
if _zm_version>=5do
set_zword(_screen_width_units_addr,128)
set_zword(_screen_height_units_addr,128)
set_zbyte(_font_height_units_addr,6)
set_zbyte(_font_width_units_addr,4)
i_flag=156
else
i_flag=48
end
if full_color==true do
i_flag|=1
p_flag=194
set_zbyte(_default_bg_color_addr,9)
set_zbyte(_default_fg_color_addr,2)
end
end
set_zbyte(_interpreter_flags_header_addr,i_flag)
set_zword(_peripherals_header_addr,p_flag)
set_zword(_standard_revision_num_addr,257)
_program_counter=zaddress_at_zaddress(_program_counter_header_addr)
_dictionary_mem_addr=zaddress_at_zaddress(_dictionary_header_addr)
_object_table_mem_addr=zaddress_at_zaddress(_object_table_header_addr)
_global_var_table_mem_addr=zaddress_at_zaddress(_global_var_table_header_addr)
_abbr_table_mem_addr=zaddress_at_zaddress(_abbr_table_header_addr)
_static_memory_mem_addr=zaddress_at_zaddress(_static_memory_header_addr)
_zobject_address=_object_table_mem_addr+(_zm_object_property_count>>>15)
game_id=get_zword(_file_checksum_header_addr)
if game_id==0do game_id=_static_memory_mem_addr<<16end
game_id=tohex(game_id,false)
if game_id=="16ab"do set_zbyte(.99166,1)end
if game_id=="4860"or game_id=="fc65"do set_zbyte(_screen_width_header_addr,40)end
end
function initialize_game()
setup_palette()
process_header()
reset_io_state()
setup_user_prefs()
_main_dict=build_dictionary(_dictionary_mem_addr)
call_stack_push()
top_frame().pc=_program_counter
top_frame().args=0
if#_memory_start_state==0do _memory_start_state={unpack(_memory[1])}end
_erase_window(-1)
_set_text_style(0)
update_text_colors()
story_loaded=true
cls(current_bg)
end
__gfx__
00000444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444400000
00044444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444000
00444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444400
04444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333444444444444444440
04444334444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444334444444444444440
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444444444444444
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444444444444444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344444444444444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344444444444444
44434444444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333334444444444344444444444444
44434444444333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333344444444344444444444444
44434444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333334444444344444444444444
44434444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333334444444344444444444444
444344444d5333333333330000000000000000000000000000000000000000000000000000000000000000000000333333333333333444444344444444444444
444344444d5533333331111111111111111111111111111111111111111111111111111111111111111111111111000003333333333444444344444444444444
444344444d5553333111111111111111111111111111111111111111111111111111111111111111111111111111111110033333333444444344444444444444
444344444d5555331111111111111111111111111111111111111111111111111111111111111111111111111111111111103333333444444344444444444444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344443333333344
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344446666666344
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344446668666344
444344444d5555111111111111111111111111111111111111111111111111111111111111111111111111111111111111111033333444444344446697f66344
444344444d5555111111177111111111111111111111111111111111111111111111111111111111111111111111111111111033333444444344446a777e6344
444344444d55551111111177111111111111111111111111111111111111111111111111111111111111111111111111111110333334444443444466b7d66344
444344444d555511111111177111111111111111111111111111111111111111111111111111111111111111111111111111103333344444434444666c666344
444344444d5551111111111177111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344446666666344
444344444d5551111111111117711111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111177111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111771111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111117777711111171111111111111111171111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771111111111111111771111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771111111111111111771111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111177777711117777111177777711177117711117777711111111111111111111111111111103333444444344444444444444
444344444d5551111111111777111111771111111117711111771111177117711177111771111111111111111111111111111103333444444344444444444444
444344444d5551111111111117711111771111117777711111771111177117711117771111111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771111177117711111771111177117711111177711111111111111111111111111111103333444444344444444444444
444344444d5551111111177111771111771771177117711111771771177117711177111771111111111111111111111111111103333444444344444444444444
444344444d5551111111117777711111177711117771771111177711117771771117777711111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111777777777111111111111111111111111111103333444444344444444444444
444344444d5551111111177771111111177111111111111111111111111111111771111177111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111177111111111111111111111111111111711777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111111111111111111111111111111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111777111177177711111777771111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111177111117711771117711177111111111777111177111111111111111111111111111103333444444344444444444444
444344444d5551111111117711111111177111117711771117777777111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711171111177111117711771117711111111111111777777117111111111111111111111111111103333444444344444444444444
444344444d5551111111117711771111177111117711771117711177111111111711777117111111111111111111111111111103333444444344444444444444
444344444d5551111111177777771111777711117711771111777771111111111771111177111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111777777777111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d5551111111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333444444344444444444444
444344444d555111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110333344444434444422dd44444
444344444d55511111111111111111111111111111111111111111111111111111111111111111111111111111111111111111033334444443444422222d4444
444344444d555511111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333344444434440277752d444
444344444d555511111111111111111111111111111111111111111111111111111111111111111111111111111111111111103333344444434450227772d444
444344444d5555111111111111111111111111111111111111111111111111111111111111111111111111111111111111111033333444444344502227722444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344502222722444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344550222225444
444344444d5555511111111111111111111111111111111111111111111111111111111111111111111111111111111111110333333444444344555000054444
444344444d5555551111111111111111111111111111111111111111111111111111111111111111111111111111111111103333333444444344455555544444
444344444d5555555111111111111111111111111111111111111111111111111111111111111111111111111111111110033333333444444344445555444444
444344444d5555555555111111111111111111111111111111111111111111111111111111111111111111111111110005553333333444444344444444444444
444344444d5555555555555511111111111111111111111111111111111111111111111111111111111111111111105555555333333444444344444444444444
4443444444d55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555553333444444434444422dd44444
4443444444d5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555533344444443444422222d4444
44434444444dd555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555534444444434440257752d444
4443444444444dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd444444444434450272272d444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344502722722444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344502577522444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344550222225444
44434444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444344555000054444
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444455555544444
44443444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444443444445555444444
44444334444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444334444444444444444
44444443333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
4444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444d222222222222244444444444444
444444444d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d3344d334444444444444d555555555555244444444444444
044444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444444444445244444444444440
044444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444bbbbb4445244444444444440
004444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444444444445244444444444400
000444444d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d5344d534444444444444d444444444445244444444444000
000004444d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d0344d034444444444444d000000000000244444444400000
__map__
0405060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
070707070700000000070707000000000007050700000000000502050000000000050005000000000005050500000000040607060400000001030703010000000701010100000000000404040700000005070207020000000000020000000000000000000007000000000000000300000b0b0000000000000205020000000000
000000000000000004040200010000000a050000000000000a0e0a07050000000c060c07020000000a0806010500000006060c05070000000402000000000000080402020400000002040402010000000a040f020500000000040e0400000000000000040200000000000e000000000000000000040000000804040201000000
0c0a0905030000000c0604020700000006090402070000000608060403000000080a0907040000000e020c08070000000c020e09070000000e080402010000000c0a0f05030000000c0a0e0403000000000800040000000000080004030000000804020204000000000e00070000000002040402010000000e08040001000000
040a0a0106000000000e0505060000000402060503000000000c0201060000000808060503000000000c0e01060000000c02060201000000000c0a040300000004020605050000000800040202000000080004050200000004020a07050000000804040202000000000c0e0b0900000000060a0905000000000c0a0906000000
000c0a06010000000006050304000000000c020201000000000c020403000000040e020103000000000a090506000000000a0a0503000000000a090b07000000000a040205000000000a0a0403000000000e080207000000060202010300000001020202040000000c08040406000000040a0000000000000000000e00000000
0204000000000000080c0a0f090000000c0a0609070000000c0a010106000000060a0909070000000c020601070000000c020601010000000c02010d06000000020a0e09050000000e040202070000000c08080503000000020a06050500000004020201070000000c0e0b0905000000060a0909050000000c0a090503000000
0c0a06010100000006090506040000000c0a0605050000000c020408070000000e040202010000000209090d06000000020a0a060200000002090b0f060000000a04020505000000080a0604030000000e080402070000000c04070206000000040402020200000006040e02030000000008060100000000040a040000000000
000000000000000006060600060000000b0b0000000000000b0f0b0f0b0000000f070e0f060000000d0c06030b00000007070c090f00000006030000000000000603030306000000060c0c0c0600000009060f060900000000060f06000000000000000603000000000007000000000000000000060000000c06060603000000
060d0d0d06000000060706060f000000060d0c030f000000070c0e0c070000000c0e0d0f0c0000000f030f0c0700000006030f0b060000000f0c0e06060000000e0b0f0b06000000060d0f0c06000000000600060000000000060006030000000c0603060c000000000f000f0000000003060c06030000000f0c0e0006000000
060b0b030e000000000e0b0b0e00000001070b0b07000000000e03030e000000080e0b0b0e00000000060f030e0000000c060f06060000000006090e070000000303070b0b00000006000f060f0000000c000c0d06000000030b070b0b000000070606060e00000000070f0b0900000000070b0b0b00000000060b0b06000000
00070b070300000000060b070e000000000b070303000000000e030c07000000060f06060c000000000b0b0b0e000000000b0b070300000000090b0f0e000000000b070e0d000000000b0b0c07000000000f0c030f0000000703030307000000030606060c0000000e0c0c0c0e000000060b0000000000000000000007000000
060c000000000000060b0f0b0b000000070b070b07000000060b030b06000000070b0b0b070000000f0307030f0000000f030703030000000e030b0b060000000b0b0f0b0b0000000f0606060f0000000e0c0c0d060000000b0b070b0b000000030303030f0000000f0f0b09090000000b0f0f0d09000000060b0b0b06000000
070b0b0703000000060b0b070e000000070b0b070b0000000e030f0c070000000f060606060000000b0b0b0f0e0000000b0b0b070200000009090b0f0e0000000b0b060b0b0000000b0b0e0c070000000f0c06030f0000000e0607060e000000060606060600000007060e0607000000000c0f030000000000060b0600000000
__label__
00000mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm00000
000mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm000
00mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm00
0mmmmmmlllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllmmmmmmmmmmmmmmmmm0
0mmmmllmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmllmmmmmmmmmmmmmmm0
mmmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmmmmmmmmmmmmmmm
mmmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmmmmmmmmmmmmmmm
mmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmmmmmllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllmmmmmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmmmllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllmmmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmmllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllmmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmmllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllmmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd5lllllllllll0000000000000000000000000000000000000000000000000000000000000000000000lllllllllllllllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd55lllllllggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg00000llllllllllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555llllgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg00llllllllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd5555llggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd55555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllllmmmmmmlmmmmllllllllmm
mmmlmmmmmd55555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllllmmmmmmlmmmm6666666lmm
mmmlmmmmmd55555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllllmmmmmmlmmmm6668666lmm
mmmlmmmmmd5555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllmmmmmmlmmmm6697f66lmm
mmmlmmmmmd5555ggggggg77gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllmmmmmmlmmmm6a777e6lmm
mmmlmmmmmd5555gggggggg77ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllmmmmmmlmmmm66b7d66lmm
mmmlmmmmmd5555ggggggggg77gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllmmmmmmlmmmm666c666lmm
mmmlmmmmmd555ggggggggggg77gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmm6666666lmm
mmmlmmmmmd555gggggggggggg77ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggg77gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggggg77ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77777gggggg7ggggggggggggggggg7gggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77ggg77gggg77gggggggggggggggg77gggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77ggg77gggg77gggggggggggggggg77gggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77gggggg777777gggg7777gggg777777ggg77gg77gggg77777gggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggggg777gggggg77ggggggggg77ggggg77ggggg77gg77ggg77ggg77ggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggggggg77ggggg77gggggg77777ggggg77ggggg77gg77gggg777gggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77ggg77gggg77ggggg77gg77ggggg77ggggg77gg77gggggg777gggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77ggg77gggg77g77gg77gg77ggggg77g77gg77gg77ggg77ggg77ggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77777gggggg777gggg777g77ggggg777gggg777g77ggg77777gggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggggggggggggggggggggggggggggggggggggggggggggggg777777777gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg7777gggggggg77gggggggggggggggggggggggggggggg77ggggg77gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77ggggggggg77gggggggggggggggggggggggggggggg7gg777gg7gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77ggggggggggggggggggggggggggggggggggggggggg777777gg7gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77gggggggg777gggg77g777ggggg77777gggggggggg777777gg7gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77ggggggggg77ggggg77gg77ggg77ggg77ggggggggg777gggg77gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77ggggggggg77ggggg77gg77ggg7777777ggggggggg777777gg7gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77ggg7ggggg77ggggg77gg77ggg77gggggggggggggg777777gg7gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77gg77ggggg77ggggg77gg77ggg77ggg77ggggggggg7gg777gg7gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg7777777gggg7777gggg77gg77gggg77777gggggggggg77ggggg77gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggggggggggggggggggggggggggggggggggggggggggggggg777777777gggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77gg77ggg77gg77ggggg777g77ggggggg77gggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg7g7g7g7g7g7g7gggggggg7gg7g7ggggg7g7gggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg7g7g77gg777g7g7gggggg7gg7g7ggggg777gggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77gg7g7g7g7g777ggggg777g7g7ggggg7g7gggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggggggg777ggg7g7g7ggg7g777ggg7g777gggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg777ggg7gg7gg7g7gg7gg7gggg7gg7g7gggggg77gg77g777g777gggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggggg7gg77gg7gg777gg7gg777gg7gg777ggggg7ggg7g7g777g77ggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg7ggggg7gg7gggg7gg7gggg7gg7gg7g7ggggg7g7g777g7g7g7gggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg777g777g7ggggg7g7ggg777g7ggg777ggggg777g7g7g7g7gg77gggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggg77g777g7ggg777g777g77ggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg77g77ggggggg77ggggg7ggg7g7g7gggg7ggg7ggg7gggggg777g777g7ggg777gggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg7g7g7g7ggggg7g7ggggg777g777g7gggg7ggg7ggg7gggggg77ggg7gg7ggg77ggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg7g7g77gggggg777ggggggg7g7ggg7gggg7ggg7ggg7gggggg7gggg7gg7ggg7gggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg77gg7g7ggggg7g7ggggg77gg7ggg777g777gg7gg777ggggg7ggg777gg77gg77gggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555gggggggg777gg77gggggg77g777gg77g77gg777gggggg77g7gggg77g7g7g777g77ggg77gggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg7gg7g7ggggg7gggg7gg7g7g7g7gg7gggggg7g7g7ggg7g7g777gg7gg7g7g7gggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg7gg7g7ggggggg7gg7gg777g77ggg7gggggg777g7ggg777ggg7gg7gg7g7g7g7gggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggg7gg77gggggg77ggg7gg7g7g7g7gg7gggggg7gggg77g7g7g77gg777g7g7g777gggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmmiiddmmmmm
mmmlmmmmmd555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllmmmmmmlmmmmiiiiidmmmm
mmmlmmmmmd5555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllmmmmmmlmmm0i7775idmmm
mmmlmmmmmd5555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllmmmmmmlmm50ii777idmmm
mmmlmmmmmd5555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllmmmmmmlmm50iii77iimmm
mmmlmmmmmd55555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllllmmmmmmlmm50iiii7iimmm
mmmlmmmmmd55555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllllmmmmmmlmm550iiiii5mmm
mmmlmmmmmd55555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0llllllmmmmmmlmm55500005mmmm
mmmlmmmmmd555555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg0lllllllmmmmmmlmmm555555mmmmm
mmmlmmmmmd5555555gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg00llllllllmmmmmmlmmmm5555mmmmmm
mmmlmmmmmd5555555555gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg000555lllllllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmd55555555555555ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg05555555llllllmmmmmmlmmmmmmmmmmmmmm
mmmlmmmmmmd5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555llllmmmmmmmlmmmmmiiddmmmmm
mmmlmmmmmmd55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555lllmmmmmmmlmmmmiiiiidmmmm
mmmlmmmmmmmdd5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555lmmmmmmmmlmmm0i5775idmmm
mmmlmmmmmmmmmddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddmmmmmmmmmmlmm50i7ii7idmmm
mmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmm50i7ii7iimmm
mmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmm50i5775iimmm
mmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmm550iiiii5mmm
mmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmm55500005mmmm
mmmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmmmm555555mmmmm
mmmmlmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmlmmmmm5555mmmmmm
mmmmmllmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmllmmmmmmmmmmmmmmmm
mmmmmmmlllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmm
mmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmdiiiiiiiiiiiiimmmmmmmmmmmmmm
mmmmmmmmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmdllmmmmmmmmmmmmmd555555555555immmmmmmmmmmmmm
0mmmmmmmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmmmmmmmmmmmmdmmmmmmmmmmm5immmmmmmmmmmmm0
0mmmmmmmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmmmmmmmmmmmmdmmmbbbbbmmm5immmmmmmmmmmmm0
00mmmmmmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmmmmmmmmmmmmdmmmmmmmmmmm5immmmmmmmmmmm00
000mmmmmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmd5lmmmmmmmmmmmmmdmmmmmmmmmmm5immmmmmmmmmm000
00000mmmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmd0lmmmmmmmmmmmmmd000000000000immmmmmmmm00000
__meta:title__
status line 3.0
by christopher drum
