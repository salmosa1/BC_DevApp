pageextension 99850 "ConfigPackSubf DVF" extends "Config. Package Subform"
{
    actions
    {
        addlast(processing)
        {
            group("Advanced DVF")
            {
                Caption = 'Advanced Options', Comment = 'Opciones avanzadas';
                group("Excel DVF")
                {

                }
                group("Package DVF")
                {
                    Caption = 'Package', Comment = 'Paquete';
                    action("ViewAllErrors DVF")
                    {
                        ApplicationArea = All;
                        Caption = 'View All Errors', Comment = 'Ver todos los errores';
                        Image = ErrorLog;

                        trigger OnAction();
                        var
                            confPackError: Record "Config. Package Error";
                            confPackErrors: Page "Config. Package Errors";
                        begin
                            confPackError.Reset();
                            confPackError.SetRange("Package Code", Rec."Package Code");
                            confPackError.SetRange("Table ID", Rec."Table ID");
                            confPackErrors.SetTableView(confPackError);
                            confPackErrors.Run();
                        end;
                    }
                    action("DeletePackageData DVF")
                    {
                        ApplicationArea = All;
                        Caption = 'Delete Package Data', Comment = 'Eliminar datos de paquete';
                        Image = Delete;

                        trigger OnAction();
                        var
                            confPackRec: Record "Config. Package Record";
                            confPackTab: Record "Config. Package Table";
                        begin
                            CurrPage.SetSelectionFilter(confPackTab);
                            if confPackTab.FindSet(false, false) then
                                repeat
                                    confPackRec.Reset();
                                    confPackRec.SetRange("Package Code", confPackTab."Package Code");
                                    confPackRec.SetRange("Table ID", confPackTab."Table ID");
                                    confPackRec.DeleteAll(true);
                                until confPackTab.Next() = 0;
                        end;
                    }
                }
                group("Database DVF")
                {
                    Caption = 'Database', Comment = 'BBDD';
                    action("AdvDatabaseRecords DVF")
                    {
                        ApplicationArea = All;
                        Caption = 'Datos de base de datos (Tabla)', Comment = 'Datos de base de datos (Tabla)';
                        Image = Database;

                        trigger OnAction();
                        var
                        begin
                            Hyperlink(GetTableUrl(Rec."Table ID"));
                        end;
                    }
                    action("DeleteData DVF")
                    {
                        ApplicationArea = All;
                        Caption = 'Delete Data', Comment = 'Eliminar datos';
                        Image = Delete;

                        trigger OnAction();
                        var
                            confPackFilter: Record "Config. Package Filter";
                            confPackTable: Record "Config. Package Table";
                            rRef: RecordRef;
                            fRef: FieldRef;
                            RunTrigger: Boolean;
                            Selection: Integer;
                            DeleteAllQst: Label 'There are no filters in table %1, all data will be deleted, continue?', Comment = 'No se han aplicado filtros en la tabla %1, se eliminarán todos los datos, ¿continuar?';
                            okMsg: Label 'Data deleted', Comment = 'Datos eliminados';
                            RunTriggerQst: Label 'Delete(True),Delete(False)', Comment = 'Delete(True),Delete(False)';
                        begin
                            Selection := StrMenu(RunTriggerQst, 0);
                            if Selection = 0 then
                                Error('');
                            RunTrigger := Selection = 1;

                            CurrPage.SetSelectionFilter(confPackTable);
                            if confPackTable.FindSet() then
                                repeat
                                    rRef.Open(Rec."Table ID", false, CompanyName);

                                    confPackFilter.SetRange("Package Code", confPackTable."Package Code");
                                    confPackFilter.SetRange("Table ID", confPackTable."Table ID");
                                    confPackFilter.SetRange("Processing Rule No.", 0);
                                    if confPackFilter.FindSet(false, false) then begin
                                        repeat
                                            fRef := rRef.Field(confPackFilter."Field ID");
                                            fRef.SetFilter(confPackFilter."Field Filter");
                                        until confPackFilter.Next() = 0;

                                        rRef.DeleteAll(RunTrigger);
                                    end else
                                        if Confirm(DeleteAllQst, false, confPackTable."Table ID") then
                                            rRef.DeleteAll(RunTrigger);
                                    rRef.Close();
                                until confPackTable.Next() = 0;

                            Message(okMsg);
                        end;
                    }
                }
            }
        }
        moveafter("Excel DVF"; "E&xcel")
        movefirst("Package DVF"; PackageFields)
        moveafter(PackageFields; PackageFilters)
        moveafter("ViewAllErrors DVF"; PackageRecords)
        movelast("Advanced DVF"; ApplyData)
    }

    procedure GetTableUrl(TableNo: Integer): Text
    begin
        exit(GetUrl(ClientType::Web, CompanyName(), ObjectType::Table, TableNo));
    end;
}