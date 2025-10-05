import sys
import traceback
import os

try:
    from datagen import DataGenerator, DataGenConfig
    from datetime import datetime
    
    print("✓ Imports exitosos")
    
    config = DataGenConfig(
        seed=42,
        n_users=10,  # Reducido para prueba rápida
        n_nfts=20,
        pct_nfts_in_auction=0.60
    )
    
    print("✓ Config creada")
    
    gen = DataGenerator(config, verbose=True)
    
    print("✓ Generator creado")
    print("\nEjecutando pipeline...")
    output_dir = os.path.dirname(os.path.abspath(__file__))

    gen.run_pipeline(
        phases=(2, 3, 4, 5),
        strict=True,
        export_sql_path=os.path.join(output_dir, "test_output.sql")
    )
    
    print("\n✓ Pipeline completado exitosamente!")
    
except Exception as e:
    print(f"\n✗ ERROR: {str(e)}")
    print("\nTraceback completo:")
    traceback.print_exc()
    sys.exit(1)
