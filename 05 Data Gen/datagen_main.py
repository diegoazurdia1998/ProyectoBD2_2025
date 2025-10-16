"""
Script principal para generar datos de prueba para ArteCryptoAuctions
Ejecuta el pipeline completo y exporta a SQL
"""

from datagen import DataGenerator, DataGenConfig
from datetime import datetime
import os

def main():
    # Configuración personalizada (opcional)
    config = DataGenConfig(
        seed=42,
        start_date=datetime(2024, 1, 1),
        end_date=datetime(2025, 1, 1),
        n_users=200,
        n_nfts=600,
        pct_nfts_in_auction=0.60,
        default_auction_hours=72,
        bids_per_auction_lambda=6.0
    )
    
    # Crear generador
    print("=" * 80)
    print("GENERADOR DE DATOS - ArteCryptoAuctions")
    print("=" * 80)
    print()
    
    gen = DataGenerator(config, verbose=True)
    
    # Definir ruta de salida
    output_dir = os.path.dirname(os.path.abspath(__file__))
    output_file = os.path.join(output_dir, "datos_generados_2.sql")
    
    print(f"Archivo de salida: {output_file}")
    print()
    
    # Ejecutar pipeline completo
    try:
        gen.run_pipeline(
            phases=(2, 3, 4, 5),
            strict=True,
            export_sql_path=output_file
        )
        
        print()
        print("=" * 80)
        print("✓ GENERACIÓN COMPLETADA EXITOSAMENTE")
        print("=" * 80)
        print()
        print("Resumen de datos generados:")
        print(f"  - Usuarios: {len(gen.df_user) if gen.df_user is not None else 0}")
        print(f"  - Roles asignados: {len(gen.df_userrole) if gen.df_userrole is not None else 0}")
        print(f"  - Emails: {len(gen.df_useremail) if gen.df_useremail is not None else 0}")
        print(f"  - Wallets: {len(gen.df_wallet) if gen.df_wallet is not None else 0}")
        print(f"  - NFTs: {len(gen.df_nft) if gen.df_nft is not None else 0}")
        print(f"  - Revisiones de curación: {len(gen.df_curation) if gen.df_curation is not None else 0}")
        print(f"  - Subastas: {len(gen.df_auction) if gen.df_auction is not None else 0}")
        print(f"  - Ofertas: {len(gen.df_bid) if gen.df_bid is not None else 0}")
        print(f"  - Reservas: {len(gen.df_reservation) if gen.df_reservation is not None else 0}")
        print(f"  - Ledger: {len(gen.df_ledger) if gen.df_ledger is not None else 0}")
        print(f"  - Emails: {len(gen.df_email_outbox) if gen.df_email_outbox is not None else 0}")
        print()
        print(f"Archivo SQL generado: {output_file}")
        print()
        
    except Exception as e:
        print()
        print("=" * 80)
        print("✗ ERROR EN LA GENERACIÓN")
        print("=" * 80)
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
