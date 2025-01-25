/**
@version        0.5.1
@description    odlator da plugin plsql source

*/

   
   
    /**
    @version 0.5.1
    */
    function odlator_pkg_get_data (
            p_query_type        in varchar2,   -- query ,json
            p_query             in varchar2,
            
            p_binding_type      in varchar2 default 'static', --static, pageitems, autobind 
            p_binding_static    in varchar2 default null,
            p_binding_pageitems in varchar2 default null,
            
            p_separator         in varchar2 default ','
        ) return clob as
    
        l_result_clob           clob;

        l_context_parameters    apex_exec.t_parameters :=apex_exec.c_empty_parameters;
            l_binding_names     apex_t_varchar2;
            l_binding_values    apex_t_varchar2;
            l_value             varchar2(4000);
            l_bound_params      apex_t_varchar2 := apex_t_varchar2();
        
        l_context               apex_exec.t_context;
            l_autobind          boolean;
        l_context_autobind      boolean := false;
        
        -- Variables for direct SQL handling
        --l_cursor            integer;
        --l_ignore            integer;
        --l_ref_cursor        sys_refcursor;
        
     begin
            
            <<get_binding_values>>
            begin -- get binding values into l_context_parameters
                
                
                --apex_debug.info('-info');
                --apex_debug.warn('-warn');
                --apex_debug.message('-message');
                
                --  l_binding_names
                select distinct substr(query_match,2)  -- Remove the leading colon
                    bulk collect   
                        into l_binding_names
                    from (
                        select 
                                regexp_substr(
                                    regexp_replace(
                                        regexp_replace(p_query,'--.*$','',1,0,'m'),  -- Remove single line comments
                                        '/\*.*?\*/','',1,0                           -- Remove multi-line comments
                                        ),
                                        ':[[:alnum:]_]+',     -- Match :name pattern
                                        1,level
                                ) as query_match
                             from dual
                            connect by regexp_substr(
                                    regexp_replace(
                                        regexp_replace(p_query,'--.*$','',1,0,'m'),  -- Remove single line comments
                                        '/\*.*?\*/','',1,0                           -- Remove multi-line comments
                                        ),
                                        ':[[:alnum:]_]+',     -- Match :name pattern
                                        1,level
                                ) is not null
                            )
                        
                        
                    where query_match is not null
                ;
                
                -- Process binding values depending on binding type attribut
                -- Set l_context_parameters depending on p_binding_type
                case p_binding_type
                    when 'static' then
                        l_autobind := false;
                        l_binding_values := apex_string.split(
                            p_binding_static,
                            p_separator
                        );
                        
                        apex_debug.info('values.count' || l_binding_values.count);
                        apex_debug.info('names.count'  || l_binding_names.count);
                        
                        for i in 1..l_binding_names.count loop
                            --- if not l_bound_params.exists(i) then
                                l_value := l_binding_values(least(i,l_binding_values.count));
                                                                
                                apex_debug.info('l_binding_name   (' || i || ')-'|| l_binding_names(i));
                                apex_debug.info('l_binding_value  (' || i || ')-'|| l_value);
                                
                                
                                apex_exec.add_parameter(
                                    l_context_parameters,
                                    l_binding_names(i),
                                    l_value
                                );
                                --l_bound_params.extend;
                                --l_bound_params(l_bound_params.count) := l_binding_names(i);
                           -- end if;
                        end loop;
                    when 'pageitems' then
                        l_autobind := false;
                        l_binding_values := apex_string.split(
                            p_binding_pageitems,
                            p_separator
                        );
                        for i in 1..l_binding_names.count loop
                            --if not l_bound_params.exists(i) then
                                l_value := v(l_binding_values(least(i,l_binding_values.count)));
                                apex_exec.add_parameter(
                                    l_context_parameters,
                                    l_binding_names(i),
                                    l_value
                                );
                               -- l_bound_params.extend;
                               -- l_bound_params(l_bound_params.count) := l_binding_names(i);
                            --end if;
                        end loop;
                    else -- autobind treated on get_data
                        l_autobind := true;
                        l_context_parameters := apex_exec.c_empty_parameters;
                end case;

            end get_binding_values;

            <<get_data>>
            begin
                if p_query_type = 'query' then
                    
                    <<get_data_query>>
                    begin -- assuming p_query_type = query 
                        
                        l_context := apex_exec.open_query_context(
                            p_location        => apex_exec.c_location_local_db,
                            p_sql_query       => p_query,
                            p_sql_parameters  => l_context_parameters,
                            p_auto_bind_items => l_autobind
                        );
                        
                        apex_json.initialize_clob_output(p_preserve => true);
                        apex_json.open_object;
                            apex_json.write_context(
                                p_name    => 'rows',
                                p_context => l_context
                            );
                        apex_json.close_object;
                        
                        --dbms_lob.createtemporary(l_result_clob, true);
                        l_result_clob := apex_json.get_clob_output;
                        apex_exec.close(l_context);
                        apex_json.free_output;
                        

                        exception when others then
                            apex_exec.close(l_context);
                            apex_json.free_output;
                            raise;
                    end get_data_query;     

                else if p_query_type = 'json' then
                    
                    
                    <<get_data_json>>
                    declare 
                        l_cursor    number ;--:= dbms_sql.open_cursor;
                        l_ignore    number;
                        -- l_ref_cursor        sys_refcursor;
                    begin -- json
                        l_cursor := dbms_sql.open_cursor;
                        
                        dbms_sql.parse(l_cursor, p_query, dbms_sql.native);

                        if l_context_parameters.count > 0 then
                            for i in 1..l_context_parameters.count loop
                                dbms_sql.bind_variable(
                                    l_cursor, 
                                    l_context_parameters(i).name, 
                                    l_context_parameters(i).value.varchar2_value
                                ); --TODO
                                null;
                            end loop;
                        end if;
                        
                        <<get_data_json1>>
                        begin
                            
                            -- only one column one row ??
                            dbms_sql.define_column(l_cursor, 1, l_result_clob);
                            l_ignore := dbms_sql.execute_and_fetch(l_cursor); 
                            dbms_sql.column_value(l_cursor, 1, l_result_clob); 
                            dbms_sql.close_cursor(l_cursor);
                        
                        
                        end get_data_json1;

                        exception when others then
                            apex_debug.error('get_data_json');
                            apex_debug.error(sqlerrm);
                            if dbms_sql.IS_OPEN(l_cursor) then 
                                dbms_sql.close_cursor(l_cursor);
                            end if;

                    end get_data_json;        

                else -- supposed to be using refcursor  
                    <<get_data_json2>>
                    declare 
                        l_cursor    number ;--:= dbms_sql.open_cursor;
                        l_ignore    integer;
                        l_ref_cursor        sys_refcursor;
                    begin
                        l_cursor := dbms_sql.open_cursor;
                        
                        dbms_sql.parse(l_cursor, p_query, dbms_sql.native);

                        if l_context_parameters.count > 0 then
                            for i in 1..l_context_parameters.count loop
                                dbms_sql.bind_variable(
                                    l_cursor, 
                                    l_context_parameters(i).name, 
                                    l_context_parameters(i).value.varchar2_value
                                ); --TODO
                                null;
                            end loop;
                        end if;

                        l_ignore := dbms_sql.execute_and_fetch(l_cursor); 
        
                        -- converting to sysrefcursor
                        l_ref_cursor := dbms_sql.to_refcursor(l_cursor);
                        dbms_lob.createtemporary(l_result_clob, FALSE);

                        apex_json.initialize_clob_output(p_preserve => TRUE);
                            apex_json.open_object;
                                apex_json.write( 'rows' , l_ref_cursor);-- signature 14 
                            apex_json.close_object;
                        dbms_lob.copy(l_result_clob, apex_json.get_clob_output, dbms_lob.getlength(apex_json.get_clob_output));
                        apex_json.free_output;

                        if l_ref_cursor%ISOPEN then 
                            CLOSE l_ref_cursor;
                        end if;
                        
                       
                        --    dbms_sql.close_cursor(l_cursor);
                        exception when others then
                            apex_debug.error(sqlerrm);
                            if dbms_sql.IS_OPEN(l_cursor) then 
                                dbms_sql.close_cursor(l_cursor);
                            end if;
                       
                    end get_data_json2;
                end if;   
                end if; 

            end get_data;

      --  APEX_DEBUG.INFO('l_result_clob' || l_result_clob);
      
        return l_result_clob;
        exception when others then
            --apex_debug.error(sqlerrm);
            return '{"status":"error","message":"'|| sqlerrm||'"}';
    
     end odlator_pkg_get_data;   

   


/**
* DA Plugin Render
*/
   function odlator_da_render (
      p_dynamic_action in apex_plugin.t_dynamic_action,
      p_plugin         in apex_plugin.t_plugin
   ) return apex_plugin.t_dynamic_action_render_result as
      l_da_render_result apex_plugin.t_dynamic_action_render_result;

      --da_container_id constant varchar2(255) := apex_escape.html_attribute(p_region.static_id) || '-container';
   begin
      apex_plugin_util.debug_dynamic_action(
         p_plugin         => p_plugin,
         p_dynamic_action => p_dynamic_action
      );
      -- needed libraries
      apex_javascript.add_library(
         p_name                  => 'FileSaver',
         p_directory             => p_plugin.file_prefix,
         p_check_to_add_minified => true
      );

      apex_javascript.add_library(
         p_name                  => 'odlatormodulejs',
         p_directory             => p_plugin.file_prefix,
         p_requirejs_module      => 'odlatormodulejs',
         p_check_to_add_minified => false,
         p_is_module             => true,
         p_requirejs_required    => true
      );

      apex_javascript.add_library(
         p_name                  => 'odlatorplugin',
         p_directory             => p_plugin.file_prefix,
         p_requirejs_module      => 'odlatorplugin',
         p_check_to_add_minified => false,
         p_is_module             => false
      );
      
      
      -- call the javascript(client side) function (client side) to do the render 

      l_da_render_result.javascript_function := 'mainEntry';
      l_da_render_result.ajax_identifier := apex_plugin.get_ajax_identifier;
      
    -- send attributs to js
      
      -- attribut : report name
      l_da_render_result.attribute_01 := p_dynamic_action.attribute_01;
      -- attribut : report type  
      l_da_render_result.attribute_02 := p_dynamic_action.attribute_02;
      -- attribut :  attr_binding_pageitems        
      l_da_render_result.attribute_03 := p_dynamic_action.attribute_14;
      return l_da_render_result;
   end;

/**
* Plugin AJAX
*/
   function odlator_da_ajax (
      p_dynamic_action in apex_plugin.t_dynamic_action,
      p_plugin         in apex_plugin.t_plugin
   ) return apex_plugin.t_dynamic_action_ajax_result as
      l_da_ajax_result              apex_plugin.t_dynamic_action_ajax_result;
      plugin_separator             constant p_plugin.attribute_01%type := p_plugin.attribute_01;
      --TODO : FIXME plugin_separator              constant p_plugin.attribute_01%type := p_plugin.attributes.get_varchar2('attribute_01');
      attr_report_name              constant p_dynamic_action.attribute_01%type := p_dynamic_action.attribute_01;
      attr_report_type              constant p_dynamic_action.attribute_02%type := p_dynamic_action.attribute_02;

      --static/query // 
      attr_template_type            constant p_dynamic_action.attribute_03%type := p_dynamic_action.attribute_03; 
         -- static,query from db 
      attr_template_static_filename constant p_dynamic_action.attribute_04%type := p_dynamic_action.attribute_04; 
      --attr_template_static_mimetype    constant p_dynamic_action.attribute_05%type := p_dynamic_action.attribute_05; -- ????
      attr_template_db_query        constant p_dynamic_action.attribute_06%type := p_dynamic_action.attribute_06; 

      -- json/rows TODO sql duality view
      attr_dataset_type             constant p_dynamic_action.attribute_07%type := p_dynamic_action.attribute_07; 
         -- query , json, context 
      attr_dataset_query            constant p_dynamic_action.attribute_08%type := p_dynamic_action.attribute_08;
      attr_dataset_json             constant p_dynamic_action.attribute_09%type := p_dynamic_action.attribute_09;
      attr_dataset_context          constant p_dynamic_action.attribute_10%type := p_dynamic_action.attribute_10; 

      -- binding type 
      attr_binding_type             constant p_dynamic_action.attribute_12%type := p_dynamic_action.attribute_12;
         -- static, items 
      attr_binding_values           constant p_dynamic_action.attribute_13%type := p_dynamic_action.attribute_13;
      attr_binding_pageitems        constant p_dynamic_action.attribute_14%type := p_dynamic_action.attribute_14;
      
      l_dataset_query varchar2(4000);
      l_template_blob               blob;
      l_template_mimetype           varchar2(255);
      l_template_size               number;
      l_dataset_context             apex_exec.t_context;
      l_binding_names               apex_t_varchar2;
      l_binding_values              apex_exec.t_parameters default apex_exec.c_empty_parameters;

      $IF DBMS_DB_VERSION.VERSION >= 23 $THEN
      -- 23 implentation
      -- TODO
      l_dataset clob;
      $ELSE	
      -- non 23 implementation
      l_dataset clob;
      $END
   begin
      
      begin -- retrieve template as blob
         case
            when attr_template_type = 'static' then
               begin
                  select blob_content,
                         mime_type
                    into
                     l_template_blob,
                     l_template_mimetype
                    from apex_application_files
                   where file_type = 'STATIC_FILE'
                     and flow_id = v('APP_ID')
                     and filename = attr_template_static_filename;-- 'template.odt';
               exception
                  when no_data_found then
                     raise_application_error(
                        -20001,
                        'No Template found: ' || sqlerrm
                     );
               end;
            when attr_template_type = 'query' then
               --TODO parse template query result on l_template_blob
               null;
         end case;
      end;

      begin  -- retrieve data as json
      --apex_debug.enable_dbms_output;
        case 
                when attr_dataset_type = 'query' then
                l_dataset_query :=  attr_dataset_query;
                when attr_dataset_type = 'json' then
                l_dataset_query :=  attr_dataset_json;      
        end case;          

        l_dataset := odlator_pkg_get_data(
            p_query_type        => attr_dataset_type,
            p_query             => l_dataset_query,
            p_binding_type      => attr_binding_type, -- static, pageitems,  autobin
            p_binding_static    => attr_binding_values,  -- apex_exec.t_parameters
            p_binding_pageitems => attr_binding_pageitems,
            p_separator         => coalesce(plugin_separator,',' )
        );

      end;

      begin -- send back the template to js ajax call , used by filesaver in  js
         apex_json.initialize_output(p_http_header => true);
         apex_json.flush;
         apex_json.open_object;
            apex_json.write('status','success');
            apex_json.write( 'download', 'js' );
                 
            
            -- debug
            apex_json.open_object('debug');
               apex_json.write( 'value', 'test' );
               
            apex_json.close_object;
            
            -- data
            apex_json.open_object('data');
               apex_json.write('value',l_dataset);
            apex_json.close_object;
                
            -- result
            apex_json.open_object('template');
               apex_json.write( 'mimetype',l_template_mimetype);
               -- we don't care  apex_json.write('filename', ....  );
               apex_json.write('base64',apex_web_service.blob2clobbase64(l_template_blob));--  'SGVsbG8gV29ybGQ='); 
            apex_json.close_object;

         apex_json.close_object;
      end;
      return l_da_ajax_result;
   exception
      when others then
         apex_debug.error(p_dynamic_action.action || ' raised an error while loading data.');
         --apex_exec.close(l_da_query_context);
         apex_json.close_all;
         raise;
   end;
$IF DBMS_DB_VERSION.VERSION >= 23.99 $THEN
-- MLE implentation
$ELSE	
-- non MLE implementation
$END