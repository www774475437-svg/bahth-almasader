import 'package:flutter/material.dart';

import '../reading.dart';
import 'common.dart';

/// بطاقة هدف القراءة اليومي مع سلسلة الأيام
class GoalCard extends StatelessWidget {
  const GoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Reading.instance,
      builder: (context, _) {
        final r = Reading.instance;
        final today = r.todayPages;
        final goal = r.dailyGoal <= 0 ? 1 : r.dailyGoal;
        final f = (today / goal).clamp(0.0, 1.0).toDouble();
        final streak = r.streak;
        return AppCard(
          child: Row(
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: f,
                        strokeWidth: 6,
                        color: f >= 1 ? kGreen : kGold,
                        backgroundColor: kGold.withValues(alpha: 0.15),
                      ),
                    ),
                    Text('$today', style: titleStyle(size: 18, color: accent(context))),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f >= 1 ? 'أتممت ورد اليوم ✓' : 'ورد اليوم: $today من $goal صفحات',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      streak > 0 ? '🔥 $streak ${streak == 1 ? 'يوم' : 'أيام'} متتالية' : 'اقرأ $goal صفحات لتبدأ سلسلة الأيام 🔥',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
