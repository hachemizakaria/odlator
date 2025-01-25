-- db 19 sample query
select --json_serialize(
   json_object(
      'matrix0' value (
         select json_arrayagg(
            json_object(job,dname,
                        'emps'      value count(empno),
                        'empsnames' value listagg(ename, ',') within group( order by empno),
                        'names'     value listagg(ename, ',') within group( order by empno)
                        )
                            ) 
           from emp e
           join dept d on(e.deptno = d.deptno)
        where :P1_DEPT is null or d.deptno = :P1_DEPT

          group by job, dname
      ),
      'skills' value  ( select json_arrayagg(JSON_OBJECT(skillname,skillval))
                    from(select 'sql'        skillname,5 skillval from dual union 
                         select 'javascript' skillname,4 skillval from dual union 
                         select 'python'     skillname,3 skillval from dual 
                        )
      ),
      'name'  value 'John',
      'email' value 'contact@example.com',
      'job'   value 'developer',
      'projects' : ( select JSON_ARRAYAGG(json_object(projectid,projectname,role,startdate))
                    FROM (select 1 projectid,'Website Redesign '  projectname,'Project Lead' role,'2020-12-23' startdate from dual union
                          select 2 projectid,'Marketing Campaign' projectname,'Analyst'      role,'2024-07-05' startdate from dual union 
                          select 3 projectid,'Mobile App Dev'     projectname,'Developer'    role,'2024-12-01' startdate from dual union 
                          select 4 projectid,'Cloud Migration '   projectname,'Architect'    role,'2025-01-10' startdate from dual  
                        ) 
    )
   returning clob) as data
   -- ) as output
  from dual;


-- db 23 sample query
select --json_serialize(
   json_object(
      'matrix0' : (
         select json_arrayagg(
            json_object(job,dname,
                        'emps' : count(empno),
                        'empsnames'  : listagg(ename, ',') within group( order by empno),
                        'names' : listagg(ename, ',') within group( order by empno)
                        )
                            ) 
           from emp e
           join dept d on(e.deptno = d.deptno)
        where 10 is null or d.deptno = 30
          group by job, dname
      ),
      'skills' : ( select json_arrayagg(JSON_OBJECT(skillname,skillval))
                    from(values('sql',5), ('javascript',4), ('python',3)) t1(skillname,skillval)
      ),
      'name'  value 'John',
      'email' value 'contact@example.com',
      'job'   value 'developer',
      'projects' : ( select JSON_ARRAYAGG(json_object(projectid,projectname,role,startdate))
                    FROM (VALUES 
                        (1,'Website Redesign ','Project Lead','2020-12-23'),
                        (2,'Marketing Campaign','Analyst','2024-07-05' ),
                        (3,'Mobile App Dev','Developer','2024-12-01 '),
                        (4,'Cloud Migration ','Architect',' 2025-01-10')
                        ) t1 (projectid,projectname,role,startdate)
    )
   returning json)
   -- )
    as data
  from dual;