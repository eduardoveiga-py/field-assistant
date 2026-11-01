import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/feature_registry.dart';

class CustomizeFeaturesScreen extends ConsumerWidget {
  const CustomizeFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalizar Aplicativo')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Banner informativo sobre preservação absoluta de dados
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.primaryBlue,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preservação Total de Dados',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Escolha quais recursos deseja manter visíveis no aplicativo. Você pode alterar essas opções a qualquer momento. Desativar um recurso não exclui seus dados, nem seu histórico ou relacionamentos.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Seções por Categoria
          for (final category in FeatureCategory.values) ...[
            _buildCategorySection(context, ref, category),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    WidgetRef ref,
    FeatureCategory category,
  ) {
    final features = AppFeature.values
        .where((f) => f.category == category)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            category.title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < features.length; i++) ...[
                _buildFeatureTile(context, ref, features[i]),
                if (i < features.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: Colors.grey.withValues(alpha: 0.15),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureTile(
    BuildContext context,
    WidgetRef ref,
    AppFeature feature,
  ) {
    final isEnabled = ref.watch(isFeatureEnabledProvider(feature));

    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isEnabled ? AppTheme.primaryBlue : Colors.grey).withValues(
            alpha: 0.12,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          feature.icon,
          color: isEnabled ? AppTheme.primaryBlue : Colors.grey,
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Text(
            feature.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isEnabled ? null : Colors.grey,
            ),
          ),
          if (feature.isEssential) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Essencial',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          feature.description,
          style: TextStyle(
            fontSize: 12,
            color: isEnabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
      ),
      value: isEnabled,
      onChanged: feature.isEssential
          ? null
          : (val) async {
              await FeatureRegistry.setFeatureEnabled(ref, feature, val);
            },
    );
  }
}
