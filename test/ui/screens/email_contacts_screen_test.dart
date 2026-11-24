import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ministerio_pessoal/database/app_database.dart';
import 'package:ministerio_pessoal/database/repository.dart';
import 'package:ministerio_pessoal/inbox/email_contacts_manager.dart';
import 'package:ministerio_pessoal/ui/providers.dart';
import 'package:ministerio_pessoal/ui/screens/email_contacts_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppRepository repo;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AppRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createSubject({void Function(String)? onSelectEmail}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        home: EmailContactsScreen(onSelectEmail: onSelectEmail),
      ),
    );
  }

  group('EmailContactsScreen Tests', () {
    testWidgets(
      'exibe lista inicial de contatos com iniciais e badges de origem',
      (tester) async {
        await EmailContactsManager.saveContact(
          db,
          name: 'João Silva',
          email: 'joao.silva@exemplo.com',
          source: 'manual',
        );
        await EmailContactsManager.saveContact(
          db,
          name: 'Maria Betânia',
          email: 'maria@ministerio.org',
          source: 'field_contact',
        );

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('joao.silva@exemplo.com'), findsOneWidget);
        expect(find.text('JS'), findsOneWidget);
        expect(find.text('Manual'), findsOneWidget);

        expect(find.text('Maria Betânia'), findsOneWidget);
        expect(find.text('maria@ministerio.org'), findsOneWidget);
        expect(find.text('MB'), findsOneWidget);
        expect(find.text('Ministério'), findsOneWidget);
      },
    );

    testWidgets(
      'filtra contatos em tempo real ignorando acentuação e maiúsculas',
      (tester) async {
        await EmailContactsManager.saveContact(
          db,
          name: 'João Silva',
          email: 'joao.silva@exemplo.com',
          source: 'manual',
        );
        await EmailContactsManager.saveContact(
          db,
          name: 'Carlos Oliveira',
          email: 'carlos@dominio.com',
          source: 'manual',
        );

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('search_contacts_field'));
        expect(searchField, findsOneWidget);

        // Busca sem acento para encontrar "João"
        await tester.enterText(searchField, 'joao');
        await tester.pumpAndSettle();

        expect(find.text('João Silva'), findsOneWidget);
        expect(find.text('Carlos Oliveira'), findsNothing);

        // Busca por domínio de e-mail
        await tester.enterText(searchField, 'dominio');
        await tester.pumpAndSettle();

        expect(find.text('João Silva'), findsNothing);
        expect(find.text('Carlos Oliveira'), findsOneWidget);
      },
    );

    testWidgets(
      'valida campos obrigatórios, e-mail inválido e duplicata ao cadastrar novo contato',
      (tester) async {
        await EmailContactsManager.saveContact(
          db,
          name: 'Existente',
          email: 'existente@exemplo.com',
          source: 'manual',
        );

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        // Clica em adicionar
        final addBtn = find.byKey(const Key('btn_add_contact'));
        expect(addBtn, findsOneWidget);
        await tester.tap(addBtn);
        await tester.pumpAndSettle();

        expect(find.text('Novo Contato'), findsOneWidget);

        // 1. Tenta salvar vazio -> erro de nome
        final saveBtn = find.byKey(const Key('btn_save_contact'));
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
        expect(find.text('Informe o nome do contato.'), findsOneWidget);

        // 2. Preenche nome mas e-mail inválido
        await tester.enterText(
          find.byKey(const Key('contact_name_field')),
          'Novo Amigo',
        );
        await tester.enterText(
          find.byKey(const Key('contact_email_field')),
          'email-invalido',
        );
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Informe um endereço de e-mail válido.'),
          findsOneWidget,
        );

        // 3. Preenche e-mail já existente -> erro de duplicata
        await tester.enterText(
          find.byKey(const Key('contact_email_field')),
          'existente@exemplo.com',
        );
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();
        expect(
          find.text('Já existe um contato com o e-mail existente@exemplo.com.'),
          findsOneWidget,
        );

        // 4. Preenche e-mail válido novo -> sucesso
        await tester.enterText(
          find.byKey(const Key('contact_email_field')),
          'novo.amigo@exemplo.com',
        );
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(find.text('Contato salvo com sucesso!'), findsOneWidget);
        expect(find.text('Novo Amigo'), findsOneWidget);
        expect(find.text('novo.amigo@exemplo.com'), findsOneWidget);
      },
    );

    testWidgets('permite editar um contato existente com sucesso', (
      tester,
    ) async {
      await EmailContactsManager.saveContact(
        db,
        name: 'Nome Antigo',
        email: 'contato@teste.com',
        source: 'manual',
      );

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final editBtn = find.byKey(
        const ValueKey('btn_edit_contact_contato@teste.com'),
      );
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Editar Contato'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('contact_name_field')),
        'Nome Atualizado',
      );
      await tester.enterText(
        find.byKey(const Key('contact_email_field')),
        'atualizado@teste.com',
      );

      final saveBtn = find.byKey(const Key('btn_save_contact'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Contato atualizado com sucesso!'), findsOneWidget);
      expect(find.text('Nome Atualizado'), findsOneWidget);
      expect(find.text('atualizado@teste.com'), findsOneWidget);
      expect(find.text('Nome Antigo'), findsNothing);
    });

    testWidgets('exclui contato após confirmação', (tester) async {
      await EmailContactsManager.saveContact(
        db,
        name: 'Contato Para Excluir',
        email: 'excluir@teste.com',
        source: 'manual',
      );

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Contato Para Excluir'), findsOneWidget);

      final deleteBtn = find.byKey(
        const ValueKey('btn_delete_contact_excluir@teste.com'),
      );
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.text('Excluir contato?'), findsOneWidget);

      // Clica em Cancelar primeiro
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Contato Para Excluir'), findsOneWidget);

      // Clica em Excluir novamente e confirma
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // No diálogo de confirmação, clica no botão Excluir com key
      final confirmDeleteBtn = find.byKey(
        const Key('btn_confirm_delete_contact'),
      );
      await tester.tap(confirmDeleteBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('Contato "excluir@teste.com" removido.'),
        findsOneWidget,
      );
      expect(find.text('Contato Para Excluir'), findsNothing);
    });

    testWidgets('seleciona e-mail chamando callback onSelectEmail', (
      tester,
    ) async {
      String? selected;
      await EmailContactsManager.saveContact(
        db,
        name: 'Irmão Lucas',
        email: 'lucas@teocratico.com',
        source: 'manual',
      );

      await tester.pumpWidget(
        createSubject(onSelectEmail: (email) => selected = email),
      );
      await tester.pumpAndSettle();

      final sendBtn = find.byKey(
        const ValueKey('btn_send_email_lucas@teocratico.com'),
      );
      expect(sendBtn, findsOneWidget);
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(selected, 'lucas@teocratico.com');
    });

    testWidgets(
      'filtra por etiquetas (FilterChips) e busca textual sem acentos em tags',
      (tester) async {
        await EmailContactsManager.saveContact(
          db,
          name: 'Pedro Ancião',
          email: 'pedro@congregacao.org',
          source: 'manual',
          tags: ['Anciãos', 'Congregação'],
        );
        await EmailContactsManager.saveContact(
          db,
          name: 'Lucia Silva',
          email: 'lucia@familia.org',
          source: 'manual',
          tags: ['Família'],
        );

        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        // Barra horizontal de etiquetas exibida com "Todas" e as tags cadastradas
        expect(find.byKey(const Key('tag_filter_all')), findsOneWidget);
        expect(find.byKey(const Key('tag_filter_Anciãos')), findsOneWidget);
        expect(find.byKey(const Key('tag_filter_Congregação')), findsOneWidget);
        expect(find.byKey(const Key('tag_filter_Família')), findsOneWidget);

        // Seleciona etiqueta "Família"
        await tester.tap(find.byKey(const Key('tag_filter_Família')));
        await tester.pumpAndSettle();

        expect(find.text('Lucia Silva'), findsOneWidget);
        expect(find.text('Pedro Ancião'), findsNothing);

        // Limpa selecionando "Todas"
        await tester.tap(find.byKey(const Key('tag_filter_all')));
        await tester.pumpAndSettle();
        expect(find.text('Pedro Ancião'), findsOneWidget);
        expect(find.text('Lucia Silva'), findsOneWidget);

        // Busca textual sem acento deve casar com a tag "Congregação"
        await tester.enterText(
          find.byKey(const Key('search_contacts_field')),
          'congregacao',
        );
        await tester.pumpAndSettle();
        expect(find.text('Pedro Ancião'), findsOneWidget);
        expect(find.text('Lucia Silva'), findsNothing);

        // Combina filtro de etiqueta + busca sem correspondência -> estado vazio + limpar filtros
        await tester.tap(find.byKey(const Key('tag_filter_Família')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('btn_clear_contact_filters')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('btn_clear_contact_filters')));
        await tester.pumpAndSettle();
        expect(find.text('Pedro Ancião'), findsOneWidget);
        expect(find.text('Lucia Silva'), findsOneWidget);
      },
    );

    testWidgets(
      'cadastra contato com etiquetas padrão e personalizada e permite editar tags',
      (tester) async {
        await tester.pumpWidget(createSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_add_contact')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('contact_name_field')),
          'Mateus Pioneiro',
        );
        await tester.enterText(
          find.byKey(const Key('contact_email_field')),
          'mateus@pioneiro.org',
        );

        // Seleciona etiqueta padrão "Congregação"
        final congChip = find.byKey(
          const ValueKey('contact_dialog_tag_Congregação'),
        );
        await tester.ensureVisible(congChip);
        await tester.tap(congChip);
        await tester.pumpAndSettle();

        // Adiciona etiqueta personalizada via botão + e uma pendente no campo ao salvar
        final customField = find.byKey(const Key('contact_custom_tag_field'));
        await tester.ensureVisible(customField);
        await tester.enterText(customField, 'Pioneiros');
        await tester.tap(find.byKey(const Key('btn_add_custom_tag')));
        await tester.pumpAndSettle();

        // Também testa digitar outra tag personalizada sem clicar em '+' antes de Salvar
        await tester.enterText(customField, 'Circuito');
        await tester.tap(find.byKey(const Key('btn_save_contact')));
        await tester.pumpAndSettle();

        expect(find.text('Contato salvo com sucesso!'), findsOneWidget);
        expect(find.text('Mateus Pioneiro'), findsOneWidget);
        expect(find.byKey(const Key('tag_filter_Pioneiros')), findsOneWidget);
        expect(find.byKey(const Key('tag_filter_Circuito')), findsOneWidget);

        // Edita o contato: remove 'Circuito', testa deduplicação case-insensitive de 'família' -> 'Família'
        await tester.tap(
          find.byKey(const ValueKey('btn_edit_contact_mateus@pioneiro.org')),
        );
        await tester.pumpAndSettle();

        final circuitoChip = find.byKey(
          const ValueKey('contact_dialog_tag_Circuito'),
        );
        await tester.ensureVisible(circuitoChip);
        await tester.tap(circuitoChip);
        await tester.pumpAndSettle();

        final editCustomField = find.byKey(
          const Key('contact_custom_tag_field'),
        );
        await tester.ensureVisible(editCustomField);
        await tester.enterText(editCustomField, 'família');
        await tester.tap(find.byKey(const Key('btn_add_custom_tag')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('btn_save_contact')));
        await tester.pumpAndSettle();

        final saved = await EmailContactsManager.loadSavedContacts(db);
        final mateus = saved.firstWhere(
          (c) => c.email == 'mateus@pioneiro.org',
        );
        expect(mateus.tags, equals(['Congregação', 'Pioneiros', 'Família']));
      },
    );
  });
}
