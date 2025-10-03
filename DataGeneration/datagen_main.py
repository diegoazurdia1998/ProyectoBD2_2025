from datagen_fase1 import DataGenerator, DataGenConfig

gen = DataGenerator(DataGenConfig(), verbose=True)
# Esto fallará (a propósito) si strict=True, porque aún no están implementados los métodos de las fases:
# gen.run_pipeline(strict=True)

# Si quieres que “salte” lo que aún no existe:
gen.run_pipeline(strict=False)  # mostrará qué métodos omite
