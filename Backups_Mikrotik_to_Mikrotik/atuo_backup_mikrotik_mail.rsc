# Guardem la data actual en una variable local.
:local currentDate [/system clock get date]

# Realitzem el backup en format backup.
system backup save dont-encrypt=yes name="NOM FITXER BACKUP";

# Creem un delay de 3 segons de la primer comanda
:delay 3;

# Realitzem el backup en format export. 
export file="NOM FITXER EXPORT";

# Realitzem l'enviament per correu. 
tool e-mail send to="mikrotik@indaleccius.com" subject=("ASSUMPTE CORREU - " . $currentDate) file=NOM FITXER BACKUP.backup,NOM FITXER EXPORT.rsc;

# Creem delay de 3 segons.
:delay 3;

# Una vegada enviats els fitxers de backup, els eliminem perque no s'acumulin.
file remove NOM FITXER BACKUP.backup
file remove NOM FITXER EXPORT.rsc
