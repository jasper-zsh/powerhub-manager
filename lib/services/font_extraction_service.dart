import 'dart:collection';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/models/switch_hub/switch_definition.dart';
import 'package:app/models/switch_hub/ui_config.dart';

/// Service for extracting text content from SwitchHub orchestration configuration
/// for font generation purposes
class FontExtractionService {
  /// Extract all unique characters from SwitchHub configuration
  ///
  /// [config] - The SwitchHub configuration containing UI text
  ///
  /// Returns a Set of unique Unicode characters found in the configuration
  static Set<String> extractUniqueCharacters(SwitchHubConfig config) {
    final characters = <String>{};

    for (final switchHub in config.switches) {
      // Extract from UI configuration if present
      if (switchHub.uiConfig != null) {
        _extractFromUiConfig(switchHub.uiConfig!, characters);
      }

      // Extract from logic nodes (labels, descriptions, etc.)
      _extractFromLogicNode(switchHub.onLogic, characters);
      _extractFromLogicNode(switchHub.offLogic, characters);
    }

    return characters;
  }

  /// Extract all text strings from SwitchHub configuration
  ///
  /// [config] - The SwitchHub configuration containing UI text
  ///
  /// Returns a List of all text strings found in the configuration
  static List<String> extractTextStrings(SwitchHubConfig config) {
    final textStrings = <String>[];

    for (final switchHub in config.switches) {
      // Extract from UI configuration if present
      if (switchHub.uiConfig != null) {
        _extractStringsFromUiConfig(switchHub.uiConfig!, textStrings);
      }

      // Extract from logic nodes
      _extractStringsFromLogicNode(switchHub.onLogic, textStrings);
      _extractStringsFromLogicNode(switchHub.offLogic, textStrings);
    }

    return textStrings;
  }

  /// Extract characters from UI configuration
  static void _extractFromUiConfig(
    SwitchHubUiConfig uiConfig,
    Set<String> characters,
  ) {
    if (uiConfig.channelLabel != null) {
      characters.addAll(uiConfig.channelLabel!.split(''));
    }
    if (uiConfig.onLabel != null) {
      characters.addAll(uiConfig.onLabel!.split(''));
    }
    if (uiConfig.offLabel != null) {
      characters.addAll(uiConfig.offLabel!.split(''));
    }

    // Extract from status slots if they contain text
    for (final slot in uiConfig.statusSlots) {
      // Status slots might contain format strings or labels
      // This is a placeholder for future status slot text extraction
      // Implementation depends on how status slots store text data
    }
  }

  /// Extract text strings from UI configuration
  static void _extractStringsFromUiConfig(
    SwitchHubUiConfig uiConfig,
    List<String> textStrings,
  ) {
    if (uiConfig.channelLabel != null && uiConfig.channelLabel!.isNotEmpty) {
      textStrings.add(uiConfig.channelLabel!);
    }
    if (uiConfig.onLabel != null && uiConfig.onLabel!.isNotEmpty) {
      textStrings.add(uiConfig.onLabel!);
    }
    if (uiConfig.offLabel != null && uiConfig.offLabel!.isNotEmpty) {
      textStrings.add(uiConfig.offLabel!);
    }
  }

  /// Extract characters from logic node
  static void _extractFromLogicNode(dynamic logicNode, Set<String> characters) {
    // This is a simplified implementation
    // In a full implementation, you would traverse the logic tree
    // and extract any text from conditions, descriptions, etc.

    // For now, we'll focus on UI text which is the primary use case
    // Logic nodes typically contain boolean expressions and command references
    // rather than displayable text
  }

  /// Extract text strings from logic node
  static void _extractStringsFromLogicNode(
    dynamic logicNode,
    List<String> textStrings,
  ) {
    // Similar to _extractFromLogicNode, this would traverse the logic tree
    // and extract any human-readable text

    // For now, we focus on UI text from the UI configuration
  }

  /// Get common Chinese and Latin characters that should be included
  /// in addition to the extracted characters
  static Set<String> getCommonCharacters() {
    final commonChars = <String>{};

    // Add common Latin characters (numbers, letters, punctuation)
    commonChars.addAll('0123456789'.split(''));
    commonChars.addAll('ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''));
    commonChars.addAll('abcdefghijklmnopqrstuvwxyz'.split(''));
    commonChars.addAll(' !@#\$%^&*()_+-=[]{}|;:,.<>?/'.split(''));

    // Add common Chinese punctuation and characters
    commonChars.addAll(
      '，。！？；：""'
              '（）【】《》'
          .split(''),
    );
    commonChars.addAll(
      '的一是在不了有和人这中大为上个国我以要他时来用们生到作地于出就分对成会可主发年动同工也能下过子说产种面而方后多定行学法所民得经十三之进着等部度家电力里如水化高自二理起小物现实加量都两体制机当使点从业本去把性好应开它合还因由其些然前外天政四日那社义事平形相全表间样与关各重新线内数正心反你明看原又么利比或但质气第向道命此变条只没结解问意建月公无系军很情者最立代想已通并提直题党程展五果料象员革位入常文总次品式活设及管特件长求老头基资边流路级少图山统接知较将组见计别她手角期根论运农指几九区强放决西被干做必战先回则任取据处队南给色光门即保治北造百规热领七海口东导器压志世金增争济阶油思术极交受联什认六共权收证改清己美再采转更单风切打白教速花带安场身车例真务具万每目至达走积示议声报斗完类八离华名确才科张信马节话米整空元况今集温传土许步群广石记需段研界拉林律叫且究观越织装影算低持音众书布复容儿须际商非验连断深难近矿千周委素技备半办青省列习响约支般史感劳便团往酸历市克何除消构府称太准精值号率族维划选标写存候毛亲快效斯院查江型眼王按格养易置派层片始却专状育厂京识适属圆包火住调满县局照参红细引听该铁价严龙飞'
          .split(''),
    );

    return commonChars;
  }

  /// Combine extracted characters with common characters
  static Set<String> getCharacterSet(
    SwitchHubConfig config, {
    bool includeCommonChars = true,
  }) {
    final extractedChars = extractUniqueCharacters(config);

    if (includeCommonChars) {
      extractedChars.addAll(getCommonCharacters());
    }

    return extractedChars;
  }
}
