IF (OBJECT_ID('dbo.stpCopia_Permissoes') IS NULL) EXEC('CREATE PROCEDURE dbo.stpCopia_Permissoes AS SELECT 1')
GO

ALTER PROCEDURE dbo.stpCopia_Permissoes (
    @Usuario_Origem VARCHAR(MAX),
    @Usuario_Destino VARCHAR(MAX),
    @Database VARCHAR(MAX) = '',
    @Fl_Remover_Permissoes BIT = 0,
    @Fl_Cria_Usuarios BIT = 1,
    @Fl_Exibe_Resultados BIT = 0,
    @Fl_Executar BIT = 0
)
AS BEGIN


    SET NOCOUNT ON


    ---------------------------------------------------------------------------------------
    -- CRIAÇÃO DE TABELAS
    ---------------------------------------------------------------------------------------

    IF (OBJECT_ID('tempdb..#Permissoes_Database') IS NOT NULL) DROP TABLE #Permissoes_Database
    CREATE TABLE [dbo].[#Permissoes_Database] (
        [database] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [username] [sys].[sysname] NOT NULL,
        [schema] [sys].[sysname] NULL,
        [object] [sys].[sysname] NULL,
        [cmd_state] [nvarchar] (60) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [permission_name] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [grant_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [revoke_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL
    )


    IF (OBJECT_ID('tempdb..#Permissoes_Roles') IS NOT NULL) DROP TABLE #Permissoes_Roles
    CREATE TABLE [dbo].[#Permissoes_Roles] (
        [database] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [username] [sys].[sysname] NOT NULL,
        [login_type] [sys].[sysname] NULL,
        [role] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [grant_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [revoke_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL
    )


    IF (OBJECT_ID('tempdb..#Permissoes_Servidor') IS NOT NULL) DROP TABLE #Permissoes_Servidor
    CREATE TABLE [dbo].[#Permissoes_Servidor] (
        [username] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [type_desc] [sys].[sysname] NOT NULL,
        [is_disabled] BIT NOT NULL,
        [class_desc] NVARCHAR(40) NOT NULL,
        [type] NVARCHAR(40) NOT NULL,
        [permission_name] NVARCHAR(50) NOT NULL,
        [state_desc] NVARCHAR(20) NOT NULL,
        [grant_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [revoke_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL
    )


    IF (OBJECT_ID('tempdb..#Permissoes_Roles_Servidor') IS NOT NULL) DROP TABLE #Permissoes_Roles_Servidor
    CREATE TABLE [dbo].[#Permissoes_Roles_Servidor] (
        [username] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [type_desc] [sys].[sysname] NOT NULL,
        [is_disabled] BIT NOT NULL,
        [role] [sys].[sysname] NOT NULL,
        [grant_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [revoke_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL
    )


    IF (OBJECT_ID('tempdb..#Cria_Usuarios') IS NOT NULL) DROP TABLE #Cria_Usuarios
    CREATE TABLE [dbo].[#Cria_Usuarios] (
        [database] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [username] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [type_desc] [sys].[sysname] NOT NULL,
        [default_schema_name] [nvarchar] (128) NULL,
        [authentication_type_desc] [nvarchar] (128) NULL,
        [grant_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL,
        [revoke_command] [nvarchar] (MAX) COLLATE SQL_Latin1_General_CP1_CI_AI NULL
    )


    DECLARE
        @Query_Permissao_Database VARCHAR(MAX) = '
    SELECT
        DB_NAME() AS [database],
        E.[name] AS [username],
        D.[name] AS [Schema],
        C.[name] AS [Object],
        (CASE WHEN A.state_desc = ''GRANT_WITH_GRANT_OPTION'' THEN ''GRANT'' ELSE A.state_desc END) AS cmd_state,
        A.[permission_name],
        (CASE 
            WHEN C.[name] IS NULL THEN ''USE ['' + DB_NAME() + '']; '' + (CASE WHEN A.state_desc = ''GRANT_WITH_GRANT_OPTION'' THEN ''GRANT'' ELSE A.state_desc END) + '' '' + A.[permission_name] + '' TO ['' + E.[name] + ''];''
            ELSE ''USE ['' + DB_NAME() + '']; '' + (CASE WHEN A.state_desc = ''GRANT_WITH_GRANT_OPTION'' THEN ''GRANT'' ELSE A.state_desc END) + '' '' + A.[permission_name] + '' ON ['' + DB_NAME() + ''].['' + d.[name] + ''].['' + c.[name] + ''] TO ['' + E.[name] + ''];''
        END) COLLATE DATABASE_DEFAULT AS GrantCommand,
        (CASE 
            WHEN C.[name] IS NULL THEN ''USE ['' + DB_NAME() + '']; '' + ''REVOKE '' + A.[permission_name] + '' FROM ['' + E.[name] + ''];''
            ELSE ''USE ['' + DB_NAME() + '']; '' + ''REVOKE '' + A.[permission_name] + '' ON ['' + DB_NAME() + ''].['' + d.[name] + ''].['' + c.[name] + ''] FROM ['' + E.[name] + ''];''
        END) COLLATE DATABASE_DEFAULT AS RevokeCommand
    FROM
        sys.database_permissions                            A   WITH(NOLOCK)
        LEFT JOIN sys.schemas                               B   WITH(NOLOCK) ON A.major_id = B.[schema_id]
        LEFT JOIN sys.all_objects                           C   WITH(NOLOCK)
        JOIN sys.schemas                                    D   WITH(NOLOCK) ON C.[schema_id] = D.[schema_id] ON A.major_id = C.[object_id]
        JOIN sys.database_principals                        E   WITH(NOLOCK) ON A.grantee_principal_id = E.principal_id
    WHERE
        E.[name] IN (''' + @Usuario_Origem + ''', ''' + @Usuario_Destino + ''')'



    DECLARE @Query_Permissoes_Roles VARCHAR(MAX) = '
    SELECT
        DB_NAME() AS [database],
        A.[name] AS [username],
	    A.[type_desc] AS LoginType,
	    C.[name] AS [role],
        ''EXEC ['' + DB_NAME() + ''].sys.sp_addrolemember '''''' + C.[name] + '''''', '''''' + a.[name] + '''''';'' AS GrantCommand,
        ''EXEC ['' + DB_NAME() + ''].sys.sp_droprolemember '''''' + C.[name] + '''''', '''''' + a.[name] + '''''';'' AS RevokeCommand
    FROM 
        sys.database_principals             A   WITH(NOLOCK)
	    JOIN sys.database_role_members      B   WITH(NOLOCK) ON A.principal_id = B.member_principal_id
        JOIN sys.database_principals        C   WITH(NOLOCK) ON B.role_principal_id = C.principal_id
    WHERE 
        A.[name] IN (''' + @Usuario_Origem + ''', ''' + @Usuario_Destino + ''')'

    

    IF (NULLIF(LTRIM(RTRIM(@Database)), '') IS NULL)
    BEGIN

    
        DECLARE @Query_Alterada VARCHAR(MAX)

        ---------------------------------------------------------------------------------------
        -- PERMISSÕES DE TODOS OS DATABASES
        ---------------------------------------------------------------------------------------

        SET @Query_Alterada = '
    USE [?];
    ' + @Query_Permissao_Database
    
    
        INSERT INTO #Permissoes_Database
        EXEC master.dbo.sp_MSforeachdb @Query_Alterada


        ---------------------------------------------------------------------------------------
        -- PERMISSÕES EM ROLES DE TODOS OS DATABASES
        ---------------------------------------------------------------------------------------

        SET @Query_Alterada = '
    USE [?];
    ' + @Query_Permissoes_Roles


        INSERT INTO #Permissoes_Roles
        EXEC master.dbo.sp_MSforeachdb @Query_Alterada


        ---------------------------------------------------------------------------------------
        -- PERMISSÕES NA INSTÂNCIA
        ---------------------------------------------------------------------------------------

        INSERT INTO #Permissoes_Servidor
        SELECT 
            A.[name],
            A.[type_desc],
            A.is_disabled,
            B.class_desc,
            B.[type],
            B.[permission_name],
            B.state_desc,
            'USE [master]; ' + B.state_desc + ' ' + B.[permission_name] + ' TO [' + A.[name] COLLATE SQL_Latin1_General_CP1_CI_AI + '];' AS GrantCommand,
            'USE [master]; REVOKE ' + B.[permission_name] + ' FROM [' + A.[name] COLLATE SQL_Latin1_General_CP1_CI_AI + '];' AS RevokeCommand
        FROM
            sys.server_principals               A   WITH(NOLOCK)
            JOIN sys.server_permissions         B   WITH(NOLOCK)    ON  A.principal_id = B.grantee_principal_id
        WHERE
            A.[name] IN (@Usuario_Origem, @Usuario_Destino)

    
        ---------------------------------------------------------------------------------------
        -- PERMISSÕES EM SERVER ROLES INSTÂNCIA
        ---------------------------------------------------------------------------------------

        INSERT INTO #Permissoes_Roles_Servidor
        SELECT 
            A.[name] AS username,
            A.[type_desc],
            A.is_disabled,
            C.[name] AS [role],
            'EXEC [master].[dbo].sp_addsrvrolemember ''' + A.[name] + ''', ''' + C.[name] + ''';' AS GrantCommand,
            'EXEC [master].[dbo].sp_dropsrvrolemember ''' + A.[name] + ''', ''' + C.[name] + ''';' AS RevokeCommand
        FROM
            sys.server_principals               A   WITH(NOLOCK)
            JOIN sys.server_role_members        B   WITH(NOLOCK)    ON  A.principal_id = B.member_principal_id
            JOIN sys.server_principals          C   WITH(NOLOCK)    ON  B.role_principal_id = C.principal_id
        WHERE
            A.[name] IN (@Usuario_Origem, @Usuario_Destino)


    END
    ELSE BEGIN
    

        ---------------------------------------------------------------------------------------
        -- PERMISSÕES DE UM DATABASE
        ---------------------------------------------------------------------------------------

        SET @Query_Permissao_Database = '
        USE [' + @Database + ']; ' + @Query_Permissao_Database

        INSERT INTO #Permissoes_Database
        EXEC(@Query_Permissao_Database)


        ---------------------------------------------------------------------------------------
        -- PERMISSÕES EM ROLES DE UM DATABASE
        ---------------------------------------------------------------------------------------

        SET @Query_Permissoes_Roles = '
        USE [' + @Database + ']; ' + @Query_Permissoes_Roles

        INSERT INTO #Permissoes_Roles
        EXEC(@Query_Permissoes_Roles)


    END

    
    ---------------------------------------------------------------------------------------
    -- CRIA OS USUÁRIOS (CASO NÃO EXISTAM)
    ---------------------------------------------------------------------------------------

    DECLARE @Comando VARCHAR(MAX) = ''

    IF (@Fl_Cria_Usuarios = 1)
    BEGIN
    

        DECLARE @Query_Cria_Usuarios VARCHAR(MAX) = '
    USE [?];

    SELECT 
        DB_NAME() AS [database],
        A.[name] AS username,
        A.[type_desc],
        A.default_schema_name,
        A.authentication_type_desc,
        ''USE ['' + DB_NAME() + '']; CREATE USER ['' + A.[name] + ''] FOR LOGIN ['' + A.[name] + ''] WITH DEFAULT_SCHEMA=['' + ISNULL(a.default_schema_name, ''dbo'') + ''];'' AS GrantCommand,
        ''USE ['' + DB_NAME() + '']; DROP USER ['' + A.[name] + ''];'' AS RevokeCommand
    FROM 
        sys.database_principals A WITH(NOLOCK)
    WHERE
        A.[name] = ''' + @Usuario_Origem + '''
        AND NOT EXISTS(SELECT NULL FROM sys.database_principals WITH(NOLOCK) WHERE [name] = ''' + @Usuario_Destino + ''')'

    
        INSERT INTO #Cria_Usuarios
        EXEC master.dbo.sp_MSforeachdb @Query_Cria_Usuarios


        DELETE FROM #Cria_Usuarios
        WHERE [database] != @Database


        SELECT
            @Comando += REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino)
        FROM
            #Cria_Usuarios
        WHERE
            username = @Usuario_Origem



        IF (@Fl_Executar = 1)
            EXEC(@Comando)
        ELSE BEGIN
            PRINT '-- Criação de usuários'
            PRINT @Comando
            PRINT ''
        END


    END

    ---------------------------------------------------------------------------------------
    -- EXECUTA AS PERMISSÕES
    ---------------------------------------------------------------------------------------


    SET @Comando = ''

    IF (@Fl_Remover_Permissoes = 1)
    BEGIN
    
        SELECT
            @Comando += revoke_command
        FROM
            #Permissoes_Database
        WHERE
            username = @Usuario_Destino

    END


    SELECT
        @Comando += REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino)
    FROM
        #Permissoes_Database
    WHERE
        username = @Usuario_Origem



    IF (@Fl_Executar = 1)
        EXEC(@Comando)
    ELSE BEGIN
        PRINT '-- Permissões de Database'
        PRINT @Comando
        PRINT ''
    END




    SET @Comando = ''

    IF (@Fl_Remover_Permissoes = 1)
    BEGIN
    
        SELECT
            @Comando += revoke_command
        FROM
            #Permissoes_Roles
        WHERE
            username = @Usuario_Destino

    END

    SELECT
        @Comando += REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino)
    FROM
        #Permissoes_Roles
    WHERE
        username = @Usuario_Origem



    IF (@Fl_Executar = 1)
        EXEC(@Comando)
    ELSE BEGIN
        PRINT '-- Permissões em Roles de Databases'
        PRINT @Comando
        PRINT ''
    END




    IF (NULLIF(LTRIM(RTRIM(@Database)), '') IS NULL)
    BEGIN
        

        SET @Comando = ''

        IF (@Fl_Remover_Permissoes = 1)
        BEGIN
    
            SELECT
                @Comando += revoke_command
            FROM
                #Permissoes_Roles_Servidor
            WHERE
                username = @Usuario_Destino

        END

        SELECT
            @Comando += REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino)
        FROM
            #Permissoes_Roles_Servidor
        WHERE
            username = @Usuario_Origem




        IF (@Fl_Executar = 1)
            EXEC(@Comando)
        ELSE BEGIN
            PRINT '-- Permissões em roles da instância'
            PRINT @Comando
            PRINT ''
        END


        SET @Comando = ''

        IF (@Fl_Remover_Permissoes = 1)
        BEGIN
    
            SELECT
                @Comando += revoke_command
            FROM
                #Permissoes_Servidor
            WHERE
                username = @Usuario_Destino

        END


        SELECT
            @Comando += REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino)
        FROM
            #Permissoes_Servidor
        WHERE
            username = @Usuario_Origem



        IF (@Fl_Executar = 1)
            EXEC(@Comando)
        ELSE BEGIN
            PRINT '-- Permissões na instância'
            PRINT @Comando
            PRINT ''
        END

    END



    IF (@Fl_Exibe_Resultados = 1)
    BEGIN
        

        SELECT 
            [database],
            username,
            [schema],
            [object],
            cmd_state,
            [permission_name],
            REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino) AS grant_command,
            REPLACE(revoke_command, @Usuario_Origem, @Usuario_Destino) AS revoke_command
        FROM 
            #Permissoes_Database 
        WHERE 
            username = @Usuario_Origem


        SELECT 
            [database],
            username,
            [login_type],
            [role],
            REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino) AS grant_command,
            REPLACE(revoke_command, @Usuario_Origem, @Usuario_Destino) AS revoke_command
        FROM 
            #Permissoes_Roles 
        WHERE 
            username = @Usuario_Origem


        IF (NULLIF(LTRIM(RTRIM(@Database)), '') IS NULL)
        BEGIN

            SELECT 
                username,
                [type_desc],
                is_disabled,
                class_desc,
                [type],
                [permission_name],
                state_desc,
                REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino) AS grant_command,
                REPLACE(revoke_command, @Usuario_Origem, @Usuario_Destino) AS revoke_command
            FROM 
                #Permissoes_Servidor
            WHERE 
                username = @Usuario_Origem


            SELECT 
                username,
                [type_desc],
                is_disabled,
                [role],
                REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino) AS grant_command,
                REPLACE(revoke_command, @Usuario_Origem, @Usuario_Destino) AS revoke_command
            FROM 
                #Permissoes_Roles_Servidor
            WHERE 
                username = @Usuario_Origem


        END


        IF (@Fl_Cria_Usuarios = 1)
        BEGIN

            SELECT 
                [database],
                username,
                [type_desc],
                default_schema_name,
                authentication_type_desc,
                REPLACE(grant_command, @Usuario_Origem, @Usuario_Destino) AS grant_command,
                REPLACE(revoke_command, @Usuario_Origem, @Usuario_Destino) AS revoke_command
            FROM 
                #Cria_Usuarios
            WHERE 
                username = @Usuario_Origem

        END


    END


END
