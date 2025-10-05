# Generador de Datos - ArteCryptoAuctions

Este módulo genera datos de prueba realistas para la base de datos ArteCryptoAuctions, compatible con los triggers implementados.

## 📋 Requisitos

```bash
pip install pandas numpy
```

## 🚀 Uso Rápido

```bash
python datagen_main.py
```

Esto generará un archivo `datos_generados.sql` con todos los INSERT statements.

## 📁 Archivos

- **`datagen.py`**: Clase principal `DataGenerator` con toda la lógica de generación
- **`datagen_main.py`**: Script ejecutable que usa el generador
- **`datos_generados.sql`**: Archivo de salida con los INSERTs (generado al ejecutar)

## ⚙️ Configuración

Puedes personalizar la generación modificando `DataGenConfig` en `datagen_main.py`:

```python
config = DataGenConfig(
    seed=42,                          # Semilla para reproducibilidad
    start_date=datetime(2024, 1, 1),  # Fecha inicial
    end_date=datetime(2025, 1, 1),    # Fecha final
    n_users=200,                      # Número de usuarios
    n_nfts=600,                       # Número de NFTs
    pct_nfts_in_auction=0.60,         # % de NFTs en subasta
    default_auction_hours=72,         # Duración de subastas
    bids_per_auction_lambda=6.0       # Media de ofertas por subasta
)
```

## 📊 Datos Generados

El generador crea datos para las siguientes tablas (en orden):

### Fase 2: Configuración Base
1. **ops.Status** - Catálogo de estados del sistema
2. **core.Role** - Roles (ADMIN, ARTIST, CURATOR, BIDDER)
3. **core.User** - Usuarios del sistema
4. **dbo.NFTSettings** - Configuración de validación de NFTs
5. **auction.AuctionSettings** - Configuración de subastas

### Fase 3: Datos de Usuario y NFTs
6. **core.UserRole** - Asignación de roles a usuarios
7. **core.UserEmail** - Emails de usuarios (1-2 por usuario, 1 primario)
8. **core.Wallet** - Wallets con balances en ETH
9. **nft.NFT** - NFTs con estados PENDING, APPROVED, REJECTED

### Fase 4: Curación, Subastas y Finanzas
10. **admin.CurationReview** - Revisiones de curación
11. **auction.Auction** - Subastas activas/completadas
12. **auction.Bid** - Ofertas en subastas
13. **finance.FundsReservation** - Reservas de fondos
14. **finance.Ledger** - Registro contable
15. **audit.EmailOutbox** - Emails del sistema

## 🔄 Pipeline de Generación

El generador ejecuta 4 fases:

```
Fase 2: Configuración → Fase 3: Usuarios/NFTs → Fase 4: Subastas → Fase 5: Exportar SQL
```

## ✅ Validaciones Implementadas

El generador respeta todas las restricciones de la base de datos:

- ✅ **Roles**: Cada usuario tiene 1-3 roles con probabilidades configurables
- ✅ **Emails**: Un email primario por usuario, emails únicos globalmente
- ✅ **Wallets**: `ReservedETH <= BalanceETH`
- ✅ **NFTs**: Dimensiones y tamaños dentro de rangos de NFTSettings
- ✅ **Curación**: Decisiones coherentes con estado del NFT
- ✅ **Subastas**: Solo NFTs APPROVED, fechas válidas
- ✅ **Ofertas**: Incrementos válidos, bidder ≠ artista
- ✅ **Finanzas**: Ledger balanceado, reservas aplicadas

## 🎯 Compatibilidad con Triggers

Los datos generados son **100% compatibles** con los triggers consolidados:

### `nft.tr_NFT_InsertFlow`
- ✅ Usuarios tienen rol ARTIST
- ✅ Emails primarios configurados
- ✅ Dimensiones dentro de NFTSettings
- ✅ HashCode único (64 caracteres hex)

### `admin.tr_CurationReview_Decision`
- ✅ Decisiones PENDING/APPROVED/REJECTED
- ✅ ReviewedAtUtc coherente con decisión

### `nft.tr_NFT_CreateAuction`
- ✅ NFTs APPROVED tienen ApprovedAtUtc
- ✅ Subastas creadas automáticamente

### `auction.tr_Bid_Validation`
- ✅ Ofertas > precio actual
- ✅ Bidder ≠ Artista
- ✅ Subastas activas

## 📝 Ejemplo de Uso Avanzado

```python
from datagen import DataGenerator, DataGenConfig

# Configuración personalizada
config = DataGenConfig(
    seed=123,
    n_users=500,
    n_nfts=1000,
    role_probs={
        "ADMIN": 0.02,
        "ARTIST": 0.30,
        "CURATOR": 0.10,
        "BIDDER": 0.90
    }
)

# Crear generador
gen = DataGenerator(config, verbose=True)

# Ejecutar solo fases específicas
gen.run_pipeline(phases=(2, 3), strict=True)

# Acceder a los DataFrames generados
print(gen.df_user.head())
print(gen.df_nft.head())

# Exportar a SQL
gen.run_pipeline(phases=(5,), export_sql_path="mi_archivo.sql")
```

## 🔍 Verificación de Datos

Después de generar los datos, puedes verificar:

```python
# Verificar que todos los artistas tienen rol ARTIST
artists = set(gen.df_nft["ArtistId"])
artist_role_id = gen.df_role.query("Name=='ARTIST'")["RoleId"].iloc[0]
artists_with_role = set(gen.df_userrole.query("RoleId==@artist_role_id")["UserId"])
assert artists.issubset(artists_with_role), "Todos los artistas deben tener rol ARTIST"

# Verificar emails primarios
primary_emails = gen.df_useremail.query("IsPrimary==1").groupby("UserId").size()
assert (primary_emails == 1).all(), "Cada usuario debe tener exactamente 1 email primario"

# Verificar wallets
assert (gen.df_wallet["ReservedETH"] <= gen.df_wallet["BalanceETH"]).all(), "Reserved <= Balance"
```

## 🐛 Troubleshooting

### Error: "Faltan users/roles"
- Asegúrate de ejecutar las fases en orden (2, 3, 4, 5)
- No omitas la Fase 2 que genera datos base

### Error: "No module named 'pandas'"
```bash
pip install pandas numpy
```

### Los datos no se insertan correctamente
- Verifica que la base de datos tenga los triggers instalados
- Revisa que los esquemas existan (ops, core, nft, auction, etc.)
- Ejecuta primero el DDL, luego los triggers, luego los datos

## 📚 Estructura de Datos

### Distribución de Estados NFT
- APPROVED: ~65%
- PENDING: ~20%
- REJECTED: ~15%

### Distribución de Roles
- ADMIN: ~5%
- ARTIST: ~25%
- CURATOR: ~8%
- BIDDER: ~85%

(Los usuarios pueden tener múltiples roles con probabilidad del 35%)

### Ofertas por Subasta
- Distribución: Poisson(λ=6.0)
- Incremento: 5% mínimo + factor aleatorio (1.0-3.0)

## 🔗 Integración con Triggers

Los datos generados están diseñados para **probar el flujo completo** de los triggers:

1. **Inserción de NFT** → Trigger valida y asigna curador
2. **Decisión de curador** → Trigger actualiza estado y crea subasta si aprobado
3. **Creación de subasta** → Trigger notifica a usuarios
4. **Ofertas** → Trigger valida y actualiza líder

## 📄 Licencia

Proyecto académico - Universidad - Bases de Datos 2

---

**Versión**: 1.0  
**Fecha**: 2025-01-05  
**Autor**: Equipo ArteCryptoAuctions
