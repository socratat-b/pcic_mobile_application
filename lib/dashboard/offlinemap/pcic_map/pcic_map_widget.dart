import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/utils/components/empty_lists/empty_lists_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'pcic_map_model.dart';
export 'pcic_map_model.dart';

class PcicMapWidget extends StatefulWidget {
  const PcicMapWidget({super.key});

  @override
  State<PcicMapWidget> createState() => _PcicMapWidgetState();
}

class _PcicMapWidgetState extends State<PcicMapWidget>
    with TickerProviderStateMixin {
  late PcicMapModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PcicMapModel());

    _model.tabBarController = TabController(
      vsync: this,
      length: 2,
      initialIndex: 0,
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Text(
            FFLocalizations.of(context).getText(
              'idur2ho8' /* Offline Map */,
            ),
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: FlutterFlowTheme.of(context).headlineMediumFamily,
                  color: Colors.white,
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  useGoogleFonts: GoogleFonts.asMap().containsKey(
                      FlutterFlowTheme.of(context).headlineMediumFamily),
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 2.0,
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _model.tabBarController,
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: custom_widgets.SearchableMapWidget(
                      width: double.infinity,
                      height: double.infinity,
                      accessToken: FFAppState().accessToken,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final listOfDownloads = FFAppState()
                          .listOfMapDownloads
                          .map((e) => e)
                          .toList();
                      if (listOfDownloads.isEmpty) {
                        return Center(
                          child: EmptyListsWidget(
                            type: 'downloaded maps',
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          await actions.fetchStoreStats();
                        },
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.vertical,
                          itemCount: listOfDownloads.length,
                          itemBuilder: (context, listOfDownloadsIndex) {
                            final listOfDownloadsItem =
                                listOfDownloads[listOfDownloadsIndex];
                            return Visibility(
                              visible: listOfDownloadsIndex != null,
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 16.0, 16.0, 16.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 7.0,
                                        color: Color(0x2F1D2429),
                                        offset: Offset(
                                          0.0,
                                          3.0,
                                        ),
                                      )
                                    ],
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 8.0, 12.0, 8.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    12.0, 0.0, 8.0, 0.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  listOfDownloadsItem.storeName,
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        fontFamily:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLargeFamily,
                                                        letterSpacing: 0.0,
                                                        useGoogleFonts: GoogleFonts
                                                                .asMap()
                                                            .containsKey(
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyLargeFamily),
                                                      ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 4.0, 0.0, 0.0),
                                                  child: Text(
                                                    listOfDownloadsItem.length,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .labelSmall
                                                        .override(
                                                          fontFamily:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmallFamily,
                                                          letterSpacing: 0.0,
                                                          useGoogleFonts: GoogleFonts
                                                                  .asMap()
                                                              .containsKey(
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmallFamily),
                                                        ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 4.0, 0.0, 0.0),
                                                  child: Text(
                                                    listOfDownloadsItem.size,
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .labelSmall
                                                        .override(
                                                          fontFamily:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmallFamily,
                                                          letterSpacing: 0.0,
                                                          useGoogleFonts: GoogleFonts
                                                                  .asMap()
                                                              .containsKey(
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmallFamily),
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 4.0, 0.0),
                                          child: FlutterFlowIconButton(
                                            borderColor:
                                                FlutterFlowTheme.of(context)
                                                    .alternate,
                                            borderRadius: 8.0,
                                            borderWidth: 2.0,
                                            buttonSize: 40.0,
                                            icon: Icon(
                                              Icons.delete_forever_outlined,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .error,
                                              size: 20.0,
                                            ),
                                            onPressed: () async {
                                              await actions.deleteMapStore(
                                                context,
                                                listOfDownloadsItem
                                                    .rawStoreName,
                                              );
                                              FFAppState()
                                                  .removeAtIndexFromListOfMapDownloads(
                                                      listOfDownloadsIndex);
                                              setState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment(0.0, 0),
              child: TabBar(
                labelColor: FlutterFlowTheme.of(context).primaryText,
                unselectedLabelColor:
                    FlutterFlowTheme.of(context).secondaryText,
                labelPadding: EdgeInsets.all(10.0),
                labelStyle: FlutterFlowTheme.of(context).titleMedium.override(
                      fontFamily:
                          FlutterFlowTheme.of(context).titleMediumFamily,
                      letterSpacing: 0.0,
                      useGoogleFonts: GoogleFonts.asMap().containsKey(
                          FlutterFlowTheme.of(context).titleMediumFamily),
                    ),
                unselectedLabelStyle: TextStyle(),
                indicatorColor: FlutterFlowTheme.of(context).primary,
                padding: EdgeInsets.all(4.0),
                tabs: [
                  Tab(
                    text: FFLocalizations.of(context).getText(
                      'hopzh8rp' /* Map Search */,
                    ),
                  ),
                  Tab(
                    text: FFLocalizations.of(context).getText(
                      'xg5zqtpy' /* Downloaded */,
                    ),
                  ),
                ],
                controller: _model.tabBarController,
                onTap: (i) async {
                  [
                    () async {},
                    () async {
                      await actions.fetchStoreStats();
                    }
                  ][i]();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
