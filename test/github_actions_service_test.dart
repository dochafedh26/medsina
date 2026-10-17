import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medsina/core/services/github_actions_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'medsina_github_pat_token': ''});
  });

  group('GitHubActionsService Tests', () {
    test('All 7 autonomous agents are registered with valid workflow definitions', () {
      final agents = GitHubActionsService.availableAgents;
      expect(agents.length, 7);

      final workflows = agents.map((a) => a.workflowFile).toList();
      expect(workflows, contains('medsina_summaries_4h.yml'));
      expect(workflows, contains('medsina_cat.yml'));
      expect(workflows, contains('medsina_pearl.yml'));
      expect(workflows, contains('medsina_drugs.yml'));
      expect(workflows, contains('medsina_mementos.yml'));
      expect(workflows, contains('medsina_automation.yml'));
      expect(workflows, contains('medsina_facebook.yml'));

      for (final agent in agents) {
        expect(agent.title.isNotEmpty, true);
        expect(agent.description.isNotEmpty, true);
        expect(agent.defaultCadence.isNotEmpty, true);
      }
    });

    test('GitHub token and repository preferences get and set correctly', () async {
      expect(await GitHubActionsService.isConfigured(), false);
      expect(await GitHubActionsService.getRepo(), 'dochafedh26/medsina');

      await GitHubActionsService.setGitHubToken('ghp_test_token_1234567890');
      expect(await GitHubActionsService.isConfigured(), true);
      expect(await GitHubActionsService.getGitHubToken(), 'ghp_test_token_1234567890');

      await GitHubActionsService.setRepo('custom_owner/custom_repo');
      expect(await GitHubActionsService.getRepo(), 'custom_owner/custom_repo');
    });

    test('GitHubWorkflowRun parses JSON and calculates status correctly', () {
      final jsonSuccess = {
        'id': 101,
        'name': 'Medsina - Conduites à Tenir (CAT)',
        'event': 'workflow_dispatch',
        'status': 'completed',
        'conclusion': 'success',
        'created_at': '2026-10-16T07:15:00Z',
        'updated_at': '2026-10-16T07:16:30Z',
        'html_url': 'https://github.com/dochafedh26/medsina/actions/runs/101',
        'run_number': 42,
      };

      final runSuccess = GitHubWorkflowRun.fromJson(jsonSuccess);
      expect(runSuccess.id, 101);
      expect(runSuccess.name, 'Medsina - Conduites à Tenir (CAT)');
      expect(runSuccess.isRunning, false);
      expect(runSuccess.isSuccess, true);
      expect(runSuccess.isFailure, false);
      expect(runSuccess.runNumber, 42);

      final jsonRunning = {
        'id': 102,
        'name': 'Medsina - Résumés Automatiques de Cours (4h)',
        'event': 'schedule',
        'status': 'in_progress',
        'conclusion': null,
        'created_at': '2026-10-16T07:20:00Z',
        'updated_at': '2026-10-16T07:20:30Z',
        'html_url': 'https://github.com/dochafedh26/medsina/actions/runs/102',
        'run_number': 43,
      };

      final runRunning = GitHubWorkflowRun.fromJson(jsonRunning);
      expect(runRunning.isRunning, true);
      expect(runRunning.isSuccess, false);
    });

    test('Triggering workflow without token returns helpful error message', () async {
      final result = await GitHubActionsService.triggerWorkflow(
        workflowFileName: 'medsina_cat.yml',
      );

      expect(result.isSuccess, false);
      expect(result.message, contains('Clé GitHub PAT non configurée'));
    });
  });
}

