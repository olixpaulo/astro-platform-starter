import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  List<dynamic> _plans = [];
  String? _currentTier;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dio = ref.read(apiClientProvider);
      final plans = await dio.get('/subscriptions/plans');
      final mine = await dio.get('/subscriptions/me');
      setState(() {
        _plans = plans.data as List;
        _currentTier = mine.data == null ? 'free' : mine.data['plan']['tier'] as String;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _subscribe(String tier) async {
    try {
      await ref.read(apiClientProvider).post('/subscriptions', data: {
        'plan_tier': tier,
        // Em produção, token devolvido pelo SDK de pagamentos (Stripe)
        'payment_method_token': 'tok_demo',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscrição ativada 🎉')),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ativar a subscrição')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final plan in _plans.cast<Map<String, dynamic>>())
                  Card(
                    color: plan['tier'] == 'premium' ? scheme.primaryContainer : null,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(plan['name'] as String,
                                    style: Theme.of(context).textTheme.titleLarge),
                              ),
                              Text(
                                (plan['price_monthly_cents'] as int) == 0
                                    ? 'Grátis'
                                    : '€${((plan['price_monthly_cents'] as int) / 100).toStringAsFixed(2)}/mês',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _Feature(
                            text: plan['daily_translation_limit'] == null
                                ? 'Traduções ilimitadas'
                                : '${plan['daily_translation_limit']} traduções/dia',
                          ),
                          _Feature(text: 'Documentos até ${plan['max_document_size_mb']}MB'),
                          if (plan['premium_voices'] == true) const _Feature(text: 'Vozes premium'),
                          if (plan['ads_free'] == true) const _Feature(text: 'Sem anúncios'),
                          const SizedBox(height: 16),
                          if (_currentTier == plan['tier'])
                            const Chip(label: Text('Plano atual'))
                          else if ((plan['price_monthly_cents'] as int) > 0)
                            FilledButton(
                              onPressed: () => _subscribe(plan['tier'] as String),
                              child: const Text('Subscrever'),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
